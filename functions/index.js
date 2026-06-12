// functions/index.js

const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();

// ✅ Control básico de costo/concurrencia
setGlobalOptions({ maxInstances: 10 });

/* =========================================================
 * Helpers
 * =======================================================*/

async function sendPushToUserByUid({
  uidDestino,
  title,
  body,
  data = {},
  androidChannelId,
  logContext = {},
  saveToFirestore = true,
}) {
  if (!uidDestino) {
    logger.warn("sendPushToUserByUid: uidDestino vacío", logContext);
    return;
  }

  const userRef = admin.firestore().collection("usuarios").doc(uidDestino);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    logger.warn("Usuario destino no existe", { uidDestino, ...logContext });
    return;
  }

  const userData = userSnap.data() || {};
  const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];

  // ✅ Guardar en Firestore aunque no haya token (para la pantalla in-app)
  if (saveToFirestore) {
    try {
      await userRef.collection("notificaciones").add({
        title: title || "Notificación",
        body: body || "",
        type: data.type || "general",
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v ?? "")]),
        ),
        read: false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.error("Error guardando notificación en Firestore", {
        uidDestino,
        err: String(err),
        ...logContext,
      });
    }
  }

  if (!tokens.length) {
    logger.warn("Usuario sin fcmTokens, notificación solo guardada en Firestore", {
      uidDestino,
      ...logContext,
    });
    return;
  }

  const message = {
    tokens,
    notification: {
      title: title || "Notificación",
      body: body || "Tienes una nueva notificación",
    },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v ?? "")]),
    ),
    android: {
      priority: "high",
      ...(androidChannelId
        ? {
            notification: {
              channelId: androidChannelId,
            },
          }
        : {}),
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);

  logger.info("Push enviada", {
    uidDestino,
    title,
    successCount: response.successCount,
    failureCount: response.failureCount,
    ...logContext,
  });

  const invalidTokens = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code || "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[i]);
      }

      logger.error("Error enviando push a token", {
        uidDestino,
        token: tokens[i],
        code,
        message: r.error?.message,
        ...logContext,
      });
    }
  });

  if (invalidTokens.length) {
    const cleanedTokens = tokens.filter((t) => !invalidTokens.includes(t));
    await userRef.update({ fcmTokens: cleanedTokens });

    logger.info("Tokens inválidos eliminados", {
      uidDestino,
      invalidCount: invalidTokens.length,
      ...logContext,
    });
  }
}

async function sendPushToManyUids({
  uids = [],
  title,
  body,
  data = {},
  androidChannelId,
  logContext = {},
}) {
  const uniqueUids = [...new Set(uids.filter(Boolean))];
  for (const uid of uniqueUids) {
    await sendPushToUserByUid({
      uidDestino: uid,
      title,
      body,
      data,
      androidChannelId,
      logContext: { ...logContext, uidDestino: uid },
    });
  }
}

function norm(v) {
  return String(v || "").trim().toLowerCase();
}

// ✅ Reutilizado por los recordatorios programados: dado un conjunto de
// almacenes, devuelve los UIDs de los admins asignados a ellos (mismo
// criterio de roles/campos que usa notificarNuevoPedido).
async function getAdminUidsByAlmacenIds(almacenIds) {
  if (!almacenIds.length) return [];

  const usuariosSnap = await admin.firestore().collection("usuarios").get();

  return usuariosSnap.docs
    .filter((d) => {
      const u = d.data() || {};
      const rol = String(u.rol || u.role || "").trim().toLowerCase();
      const almacenId = String(
        u.almacenId || u.idAlmacen || u.assignedAlmacenId || "",
      ).trim();

      return rol === "admin" && almacenIds.includes(almacenId);
    })
    .map((d) => d.id);
}

/* =========================================================
 * 1) NOTIFICAR NUEVO PEDIDO A ADMINS DEL MISMO DEPARTAMENTO
 * Trigger: pedidos/{pedidoId}
 * =======================================================*/

exports.notificarNuevoPedido = onDocumentCreated(
  {
    document: "pedidos/{pedidoId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) {
        logger.warn("No hay snapshot en notificarNuevoPedido");
        return;
      }

      const pedido = snap.data() || {};
      const pedidoId = event.params.pedidoId;

      const pedidoDepto = String(
        pedido.departamento ||
          pedido?.ubicacion?.departamento ||
          pedido?.direccion?.departamento ||
          "",
      ).trim();

      if (!pedidoDepto) {
        logger.warn("Pedido sin departamento", { pedidoId });
        return;
      }

      const almacenesSnap = await admin
        .firestore()
        .collection("almacenes")
        .get();

      const almacenesIdsDepto = almacenesSnap.docs
        .filter((d) => {
          const data = d.data() || {};
          const dep = String(data.departamento || "").trim();
          return norm(dep) === norm(pedidoDepto);
        })
        .map((d) => d.id);

      if (!almacenesIdsDepto.length) {
        logger.warn("No hay almacenes en el depto del pedido", {
          pedidoId,
          pedidoDepto,
        });
        return;
      }

      const usuariosSnap = await admin.firestore().collection("usuarios").get();

      const adminUids = usuariosSnap.docs
        .filter((d) => {
          const u = d.data() || {};
          const rol = String(u.rol || u.role || "").trim().toLowerCase();
          const almacenId = String(
            u.almacenId || u.idAlmacen || u.assignedAlmacenId || "",
          ).trim();

          return rol === "admin" && almacenesIdsDepto.includes(almacenId);
        })
        .map((d) => d.id);

      if (!adminUids.length) {
        logger.warn("No se encontraron admins para el depto del pedido", {
          pedidoId,
          pedidoDepto,
          almacenesIdsDepto,
        });
        return;
      }

      await sendPushToManyUids({
        uids: adminUids,
        title: "Nuevo pedido pendiente",
        body: `Hay un nuevo pedido pendiente en ${pedidoDepto}`,
        data: {
          type: "nuevo_pedido_pendiente",
          pedidoId,
          departamento: pedidoDepto,
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarNuevoPedido",
          pedidoId,
          pedidoDepto,
          adminsCount: adminUids.length,
        },
      });
    } catch (error) {
      logger.error("Error en notificarNuevoPedido", error);
    }
  },
);

/* =========================================================
 * 2) NOTIFICAR MENSAJES DE SOPORTE
 * Trigger: support_chats/{chatId}/messages/{messageId}
 * =======================================================*/

exports.notificarMensajeSoporte = onDocumentCreated(
  {
    document: "support_chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) {
        logger.warn("No hay snapshot en notificarMensajeSoporte");
        return;
      }

      const msg = snap.data() || {};
      const { chatId, messageId } = event.params;

      const senderRole = (msg.senderRole || "").toString().trim();
      const senderName = (msg.senderName || "").toString().trim() || "Soporte";
      const type = (msg.type || "text").toString().trim();
      const text = (msg.text || "").toString().trim();

      if (senderRole === "system") {
        logger.info("Mensaje system: no se envía push", { chatId, messageId });
        return;
      }

      const chatRef = admin.firestore().collection("support_chats").doc(chatId);
      const chatSnap = await chatRef.get();

      if (!chatSnap.exists) {
        logger.warn("Chat no existe", { chatId, messageId });
        return;
      }

      const chat = chatSnap.data() || {};

      const clientUid = (
        chat.clientUid ||
        chat.uidClient ||
        chat.userUid ||
        chat.clienteUid ||
        ""
      )
        .toString()
        .trim();

      const supportUid = (chat.assignedSupportUid || "").toString().trim();
      const clientName = (chat.clientName || "Cliente").toString().trim();

      const clientInSupportChatPage = chat.clientInSupportChatPage === true;
      const supportInChatPage = chat.supportInChatPage === true;

      let uidDestino = "";
      let title = "";
      let body = "";

      if (senderRole === "support") {
        uidDestino = clientUid;

        if (clientInSupportChatPage) {
          logger.info("Cliente está en el chat, no se envía push", {
            chatId,
            messageId,
            clientUid,
          });
          return;
        }

        title = "Soporte";
        body =
          type === "image"
            ? `${senderName} te envió una imagen`
            : `${senderName}: ${text || "Nuevo mensaje"}`;
      } else if (senderRole === "client") {
        uidDestino = supportUid;

        if (supportInChatPage) {
          logger.info("Soporte está en el chat, no se envía push", {
            chatId,
            messageId,
            supportUid,
          });
          return;
        }

        title = clientName || "Cliente";
        body = type === "image" ? "📷 Imagen" : (text || "Nuevo mensaje");
      } else {
        logger.warn("senderRole no reconocido", {
          chatId,
          messageId,
          senderRole,
        });
        return;
      }

      if (!uidDestino) {
        logger.warn("No hay uidDestino para notificar en soporte", {
          chatId,
          messageId,
          senderRole,
          clientUid,
          supportUid,
        });
        return;
      }

      await sendPushToUserByUid({
        uidDestino,
        title,
        body,
        data: {
          type: "support_chat",
          chatId,
          messageId,
          senderRole,
        },
        androidChannelId: "support_chat_channel",
        logContext: { trigger: "notificarMensajeSoporte", chatId, messageId },
        saveToFirestore: false, // El chat de soporte tiene su propia UI
      });
    } catch (error) {
      logger.error("Error en notificarMensajeSoporte", error);
    }
  },
);

/* =========================================================
 * 3) NOTIFICAR AL CLIENTE CUANDO EL PEDIDO SEA ENTREGADO
 * Trigger: pedidos/{pedidoId}
 * =======================================================*/

exports.notificarPedidoEntregado = onDocumentUpdated(
  {
    document: "pedidos/{pedidoId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const beforeSnap = event.data?.before;
      const afterSnap = event.data?.after;

      if (!beforeSnap || !afterSnap) {
        logger.warn("No hay snapshots before/after en notificarPedidoEntregado");
        return;
      }

      const beforeData = beforeSnap.data() || {};
      const afterData = afterSnap.data() || {};
      const pedidoId = event.params.pedidoId;

      const estadoAntes = norm(beforeData.estado);
      const estadoDespues = norm(afterData.estado);

      if (estadoAntes === "entregado" || estadoDespues !== "entregado") {
        logger.info("No corresponde enviar push de entregado", {
          pedidoId,
          estadoAntes,
          estadoDespues,
        });
        return;
      }

      const uidCliente = String(
        afterData.clienteUid ||
          afterData.userUid ||
          afterData.usuarioUid ||
          afterData.uidCliente ||
          afterData.uidUsuario ||
          afterData.createdBy ||
          "",
      ).trim();

      if (!uidCliente) {
        logger.warn("Pedido entregado pero sin uid del cliente", {
          pedidoId,
          estadoAntes,
          estadoDespues,
        });
        return;
      }

      const codigoPedido = String(
        afterData.codigo ||
          afterData.codigoPedido ||
          "",
      ).trim();

      const titulo = "Pedido entregado";
      const cuerpo = codigoPedido
        ? `Tu pedido ${codigoPedido} fue entregado. Por favor califica la satisfacción del pedido y los productos.`
        : "Tu pedido fue entregado. Por favor califica la satisfacción del pedido y los productos.";

      await sendPushToUserByUid({
        uidDestino: uidCliente,
        title: titulo,
        body: cuerpo,
        data: {
          type: "pedido_entregado",
          pedidoId,
          estado: "Entregado",
          codigo: codigoPedido,
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarPedidoEntregado",
          pedidoId,
          uidCliente,
          codigoPedido,
        },
      });

      logger.info("Push de pedido entregado enviada correctamente", {
        pedidoId,
        uidCliente,
        codigoPedido,
      });
    } catch (error) {
      logger.error("Error en notificarPedidoEntregado", error);
    }
  },
);

/* =========================================================
 * 4) NOTIFICAR AL CLIENTE CUANDO CAMBIA EL ESTADO DE PAGO
 * Trigger: pedidos/{pedidoId}
 * =======================================================*/

exports.notificarCambioEstadoPago = onDocumentUpdated(
  {
    document: "pedidos/{pedidoId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const beforeSnap = event.data?.before;
      const afterSnap = event.data?.after;

      if (!beforeSnap || !afterSnap) {
        logger.warn("No hay snapshots before/after en notificarCambioEstadoPago");
        return;
      }

      const beforeData = beforeSnap.data() || {};
      const afterData = afterSnap.data() || {};
      const pedidoId = event.params.pedidoId;

      const estadoPagoAntes = norm(
        beforeData.estado_pago || beforeData.estadoPago,
      );
      const estadoPagoDespues = norm(
        afterData.estado_pago || afterData.estadoPago,
      );

      if (estadoPagoAntes === estadoPagoDespues) {
        logger.info("estado_pago no cambió, no se envía push", {
          pedidoId,
          estadoPagoAntes,
          estadoPagoDespues,
        });
        return;
      }

      if (estadoPagoDespues !== "rechazado" && estadoPagoDespues !== "pagado") {
        logger.info("Cambio de estado_pago no requiere push", {
          pedidoId,
          estadoPagoAntes,
          estadoPagoDespues,
        });
        return;
      }

      const uidCliente = String(
        afterData.clienteUid ||
          afterData.userUid ||
          afterData.usuarioUid ||
          afterData.uidCliente ||
          afterData.uidUsuario ||
          afterData.createdBy ||
          afterData.uid ||
          "",
      ).trim();

      if (!uidCliente) {
        logger.warn("Pedido con cambio de estado_pago pero sin uid del cliente", {
          pedidoId,
          estadoPagoAntes,
          estadoPagoDespues,
        });
        return;
      }

      const codigoPedido = String(
        afterData.codigo ||
          afterData.codigoPedido ||
          "",
      ).trim();

      let title = "";
      let body = "";
      let type = "";

      if (estadoPagoDespues === "rechazado") {
        title = "Pago rechazado";
        body = codigoPedido
          ? `El pedido ${codigoPedido} fue rechazado en la forma de pago. Toca aquí para más detalles.`
          : "Tu forma de pago fue rechazada. Toca aquí para más detalles.";
        type = "pedido_pago_rechazado";
      }

      if (estadoPagoDespues === "pagado") {
        title = "Pago aceptado";
        body = codigoPedido
          ? `Tu pedido ${codigoPedido} fue aceptado. Toca aquí para ver los detalles.`
          : "Tu pedido fue aceptado. Toca aquí para ver los detalles.";
        type = "pedido_pago_aceptado";
      }

      await sendPushToUserByUid({
        uidDestino: uidCliente,
        title,
        body,
        data: {
          type,
          pedidoId,
          codigo: codigoPedido,
          estadoPago: estadoPagoDespues,
          target: "detalle_pedido",
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarCambioEstadoPago",
          pedidoId,
          uidCliente,
          codigoPedido,
          estadoPagoAntes,
          estadoPagoDespues,
        },
      });

      logger.info("Push por cambio de estado_pago enviada correctamente", {
        pedidoId,
        uidCliente,
        codigoPedido,
        estadoPagoAntes,
        estadoPagoDespues,
      });
    } catch (error) {
      logger.error("Error en notificarCambioEstadoPago", error);
    }
  },
);

/* =========================================================
 * 5) NOTIFICAR AL CONDUCTOR CUANDO SE LE ASIGNA UN PEDIDO
 * Trigger: pedidos/{pedidoId} — cuando conductorUid cambia
 *          de vacío/null a un uid válido.
 * =======================================================*/

exports.notificarConductorAsignado = onDocumentUpdated(
  {
    document: "pedidos/{pedidoId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const beforeSnap = event.data?.before;
      const afterSnap = event.data?.after;

      if (!beforeSnap || !afterSnap) return;

      const beforeData = beforeSnap.data() || {};
      const afterData = afterSnap.data() || {};
      const pedidoId = event.params.pedidoId;

      // Leer uid del conductor con múltiples fallbacks
      const conductorAntes = String(
        beforeData.conductorUid ||
          beforeData.repartidorUid ||
          beforeData.driverUid ||
          "",
      ).trim();

      const conductorDespues = String(
        afterData.conductorUid ||
          afterData.repartidorUid ||
          afterData.driverUid ||
          "",
      ).trim();

      // Solo disparar cuando se asigna por primera vez
      if (!conductorDespues || conductorAntes === conductorDespues) {
        return;
      }

      const codigoPedido = String(
        afterData.codigo || afterData.codigoPedido || "",
      ).trim();

      const departamento = String(
        afterData.departamento ||
          afterData?.ubicacion?.departamento ||
          afterData?.direccion?.departamento ||
          "",
      ).trim();

      const title = "Nuevo pedido asignado";
      const body = codigoPedido
        ? `Se te asignó el pedido ${codigoPedido}${departamento ? ` en ${departamento}` : ""}`
        : "Se te asignó un nuevo pedido";

      await sendPushToUserByUid({
        uidDestino: conductorDespues,
        title,
        body,
        data: {
          type: "pedido_asignado",
          pedidoId,
          codigo: codigoPedido,
          departamento,
          target: "mis_pedidos",
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarConductorAsignado",
          pedidoId,
          conductorDespues,
          codigoPedido,
        },
        saveToFirestore: true,
      });

      logger.info("Notificación de asignación enviada al conductor", {
        pedidoId,
        conductorDespues,
        codigoPedido,
      });
    } catch (error) {
      logger.error("Error en notificarConductorAsignado", error);
    }
  },
);

/* =========================================================
 * 6) RECORDATORIO: PEDIDOS PENDIENTES SIN ATENDER
 * Trigger: programado, cada hora.
 *
 * A diferencia de notificarNuevoPedido (que avisa una vez al
 * crearse), este recordatorio detecta pedidos que llevan
 * varias horas en "Pendiente" sin que ningún admin los acepte
 * y vuelve a avisar — pero solo UNA vez por pedido (se marca
 * con recordatorioPendienteEnviadoAt) para no saturar.
 * =======================================================*/

const HORAS_LIMITE_PENDIENTE = 3;
const DIAS_VENTANA_PENDIENTES = 7;

exports.recordatorioPedidosPendientes = onSchedule(
  {
    schedule: "every 60 minutes",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    try {
      const ahora = Date.now();
      const limiteMs = HORAS_LIMITE_PENDIENTE * 60 * 60 * 1000;
      const desde = new Date(ahora - DIAS_VENTANA_PENDIENTES * 24 * 60 * 60 * 1000);

      const pedidosSnap = await admin
        .firestore()
        .collection("pedidos")
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(desde))
        .get();

      // Agrupar por departamento los pedidos "atascados" que aún no
      // recibieron recordatorio.
      const idsPorDepto = new Map();

      for (const doc of pedidosSnap.docs) {
        const data = doc.data() || {};

        if (norm(data.estado) !== "pendiente") continue;
        if (data.recordatorioPendienteEnviadoAt) continue;

        const createdAt = data.createdAt?.toDate?.();
        if (!createdAt || ahora - createdAt.getTime() < limiteMs) continue;

        const depto = String(
          data.departamento ||
            data?.ubicacion?.departamento ||
            data?.direccion?.departamento ||
            "",
        ).trim();
        if (!depto) continue;

        if (!idsPorDepto.has(depto)) idsPorDepto.set(depto, []);
        idsPorDepto.get(depto).push(doc.id);
      }

      if (!idsPorDepto.size) {
        logger.info("recordatorioPedidosPendientes: nada que recordar");
        return;
      }

      const almacenesSnap = await admin.firestore().collection("almacenes").get();

      for (const [depto, pedidoIds] of idsPorDepto.entries()) {
        const almacenesIdsDepto = almacenesSnap.docs
          .filter((d) => norm((d.data() || {}).departamento) === norm(depto))
          .map((d) => d.id);

        if (!almacenesIdsDepto.length) {
          logger.warn("recordatorioPedidosPendientes: depto sin almacenes", { depto });
          continue;
        }

        const adminUids = await getAdminUidsByAlmacenIds(almacenesIdsDepto);
        if (!adminUids.length) {
          logger.warn("recordatorioPedidosPendientes: depto sin admins", { depto });
          continue;
        }

        const cantidad = pedidoIds.length;

        await sendPushToManyUids({
          uids: adminUids,
          title: "Pedidos pendientes sin atender",
          body:
            cantidad === 1
              ? `Hay 1 pedido pendiente hace más de ${HORAS_LIMITE_PENDIENTE} horas en ${depto}. Revísalo.`
              : `Hay ${cantidad} pedidos pendientes hace más de ${HORAS_LIMITE_PENDIENTE} horas en ${depto}. Revísalos.`,
          data: {
            type: "recordatorio_pedidos_pendientes",
            departamento: depto,
            cantidad,
            target: "gestion_pedidos",
          },
          androidChannelId: "reminders_channel",
          logContext: {
            trigger: "recordatorioPedidosPendientes",
            depto,
            cantidad,
            adminsCount: adminUids.length,
          },
        });

        // ✅ Marcar cada pedido para no volver a recordarlo.
        const batch = admin.firestore().batch();
        for (const id of pedidoIds) {
          batch.set(
            admin.firestore().collection("pedidos").doc(id),
            { recordatorioPendienteEnviadoAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true },
          );
        }
        await batch.commit();

        logger.info("Recordatorio de pedidos pendientes enviado", {
          depto,
          cantidad,
          adminsCount: adminUids.length,
        });
      }
    } catch (error) {
      logger.error("Error en recordatorioPedidosPendientes", error);
    }
  },
);

/* =========================================================
 * 7) RECORDATORIO: STOCK BAJO (resumen diario por almacén)
 * Trigger: programado, una vez al día.
 *
 * Mismo umbral que usa el dashboard ("Stock bajo" = <= 5
 * unidades). Antes esa cifra era solo visual; ahora se avisa
 * a los admins de cada almacén para que repongan a tiempo.
 * =======================================================*/

const UMBRAL_STOCK_BAJO = 5;

exports.recordatorioStockBajo = onSchedule(
  {
    schedule: "every day 08:00",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    try {
      const productosSnap = await admin.firestore().collection("productos").get();

      // Agrupar por almacén: cuántos están con stock bajo y cuántos agotados.
      const porAlmacen = new Map();

      for (const doc of productosSnap.docs) {
        const data = doc.data() || {};
        const stock = Number(data.stock ?? 0);
        if (!Number.isFinite(stock) || stock > UMBRAL_STOCK_BAJO) continue;

        const almacenId = String(data.almacenId || "").trim();
        if (!almacenId) continue;

        if (!porAlmacen.has(almacenId)) {
          porAlmacen.set(almacenId, {
            nombre: String(data.almacenNombre || "tu almacén").trim(),
            bajos: 0,
            agotados: 0,
          });
        }

        const entry = porAlmacen.get(almacenId);
        entry.bajos += 1;
        if (stock <= 0) entry.agotados += 1;
      }

      if (!porAlmacen.size) {
        logger.info("recordatorioStockBajo: sin productos con stock bajo");
        return;
      }

      for (const [almacenId, info] of porAlmacen.entries()) {
        const adminUids = await getAdminUidsByAlmacenIds([almacenId]);
        if (!adminUids.length) {
          logger.warn("recordatorioStockBajo: almacén sin admins", { almacenId });
          continue;
        }

        const conStockBajo = info.bajos - info.agotados;
        const partes = [];
        if (info.agotados > 0) {
          partes.push(`${info.agotados} agotado${info.agotados === 1 ? "" : "s"}`);
        }
        if (conStockBajo > 0) {
          partes.push(`${conStockBajo} con stock bajo`);
        }

        await sendPushToManyUids({
          uids: adminUids,
          title: "Recordatorio: repón inventario",
          body: `${info.nombre}: ${partes.join(" y ")}. Revisa y repón antes de quedarte sin stock.`,
          data: {
            type: "recordatorio_stock_bajo",
            almacenId,
            bajos: info.bajos,
            agotados: info.agotados,
            target: "productos",
          },
          androidChannelId: "reminders_channel",
          logContext: {
            trigger: "recordatorioStockBajo",
            almacenId,
            bajos: info.bajos,
            agotados: info.agotados,
            adminsCount: adminUids.length,
          },
        });

        logger.info("Recordatorio de stock bajo enviado", {
          almacenId,
          bajos: info.bajos,
          agotados: info.agotados,
          adminsCount: adminUids.length,
        });
      }
    } catch (error) {
      logger.error("Error en recordatorioStockBajo", error);
    }
  },
);

/* =========================================================
 * 8) RECORDATORIO: ENTREGAS PROGRAMADAS PARA HOY (REPARTIDOR)
 * Trigger: programado, una vez al día (mañana).
 *
 * Le avisa a cada repartidor cuántos pedidos tiene asignados
 * con `fecha_envio` (fecha de entrega programada) dentro del
 * día de hoy, para que organice su ruta desde temprano.
 * =======================================================*/

exports.recordatorioRepartidorPedidosHoy = onSchedule(
  {
    schedule: "every day 07:00",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    try {
      const ahora = new Date();
      const inicioHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 0, 0, 0);
      const finHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 23, 59, 59, 999);

      const pedidosSnap = await admin
        .firestore()
        .collection("pedidos")
        .where("fecha_envio", ">=", admin.firestore.Timestamp.fromDate(inicioHoy))
        .where("fecha_envio", "<=", admin.firestore.Timestamp.fromDate(finHoy))
        .get();

      const cantidadPorRepartidor = new Map();

      for (const doc of pedidosSnap.docs) {
        const data = doc.data() || {};
        const estado = norm(data.estado);
        if (estado === "entregado" || estado === "cancelado") continue;

        const repartidorUid = String(
          data.conductorUid || data.repartidorUid || data.driverUid || "",
        ).trim();
        if (!repartidorUid) continue;

        cantidadPorRepartidor.set(
          repartidorUid,
          (cantidadPorRepartidor.get(repartidorUid) || 0) + 1,
        );
      }

      if (!cantidadPorRepartidor.size) {
        logger.info("recordatorioRepartidorPedidosHoy: nadie tiene entregas programadas para hoy");
        return;
      }

      for (const [uid, cantidad] of cantidadPorRepartidor.entries()) {
        await sendPushToUserByUid({
          uidDestino: uid,
          title: "Tus entregas de hoy",
          body:
            cantidad === 1
              ? "Tienes 1 pedido programado para entregar hoy. Organiza tu ruta."
              : `Tienes ${cantidad} pedidos programados para entregar hoy. Organiza tu ruta.`,
          data: {
            type: "recordatorio_entregas_hoy",
            cantidad,
            target: "mis_pedidos",
          },
          androidChannelId: "reminders_channel",
          logContext: { trigger: "recordatorioRepartidorPedidosHoy", uid, cantidad },
        });
      }

      logger.info("Recordatorio de entregas de hoy enviado", {
        repartidores: cantidadPorRepartidor.size,
      });
    } catch (error) {
      logger.error("Error en recordatorioRepartidorPedidosHoy", error);
    }
  },
);

/* =========================================================
 * 9) ALERTA: PEDIDO A PUNTO DE CAER EN RETRASO (REPARTIDOR)
 * Trigger: programado, cada 30 minutos.
 *
 * Cuando faltan ~2 horas para la `fecha_envio` (fecha/hora de
 * entrega programada) y el pedido todavía no está "Entregado",
 * se avisa al repartidor asignado para que apure la entrega
 * antes de que pase a estar retrasado. Una sola vez por pedido
 * (se marca con alertaRetrasoEnviada).
 * =======================================================*/

const HORAS_ALERTA_RETRASO = 2;

exports.alertaPedidosPorRetrasarse = onSchedule(
  {
    schedule: "every 30 minutes",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    try {
      const ahoraMs = Date.now();
      const limiteFecha = new Date(ahoraMs + HORAS_ALERTA_RETRASO * 60 * 60 * 1000);

      const pedidosSnap = await admin
        .firestore()
        .collection("pedidos")
        .where("fecha_envio", ">=", admin.firestore.Timestamp.fromDate(new Date(ahoraMs)))
        .where("fecha_envio", "<=", admin.firestore.Timestamp.fromDate(limiteFecha))
        .get();

      for (const doc of pedidosSnap.docs) {
        const data = doc.data() || {};

        const estado = norm(data.estado);
        if (estado === "entregado" || estado === "cancelado") continue;
        if (data.alertaRetrasoEnviada) continue;

        const repartidorUid = String(
          data.conductorUid || data.repartidorUid || data.driverUid || "",
        ).trim();
        if (!repartidorUid) continue;

        const fechaEnvio = data.fecha_envio?.toDate?.();
        if (!fechaEnvio) continue;

        const codigoPedido = String(data.codigo || data.codigoPedido || "").trim();
        const horaTexto = fechaEnvio.toLocaleTimeString("es-BO", {
          hour: "2-digit",
          minute: "2-digit",
        });

        await sendPushToUserByUid({
          uidDestino: repartidorUid,
          title: "Pedido a punto de retrasarse",
          body: codigoPedido
            ? `El pedido ${codigoPedido} está programado para las ${horaTexto} y aún no se entrega. Apresúrate para no generar un retraso.`
            : `Tienes una entrega programada para las ${horaTexto} que aún no se completa. Apresúrate para no generar un retraso.`,
          data: {
            type: "alerta_pedido_por_retrasarse",
            pedidoId: doc.id,
            codigo: codigoPedido,
            target: "mis_pedidos",
          },
          androidChannelId: "reminders_channel",
          logContext: {
            trigger: "alertaPedidosPorRetrasarse",
            pedidoId: doc.id,
            repartidorUid,
            codigoPedido,
          },
        });

        await doc.ref.set(
          { alertaRetrasoEnviada: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true },
        );

        logger.info("Alerta de pedido por retrasarse enviada", {
          pedidoId: doc.id,
          repartidorUid,
          codigoPedido,
        });
      }
    } catch (error) {
      logger.error("Error en alertaPedidosPorRetrasarse", error);
    }
  },
);

/* =========================================================
 * 10) RECORDATORIO: CARRITO ABANDONADO (CLIENTE)
 * Trigger: programado, una vez al día (tarde).
 *
 * Si un cliente dejó productos en `usuarios/{uid}/carrito`
 * sin moverlos por varias horas, se le recuerda completar la
 * compra. Solo se vuelve a avisar si tocó el carrito de nuevo
 * después del último aviso (carritoRecordatorioEnviadoAt), para
 * no ser invasivos.
 * =======================================================*/

const HORAS_CARRITO_ABANDONADO = 6;

function esRolCliente(rolRaw) {
  const rol = norm(rolRaw);
  if (!rol) return true;
  if (rol === "admin") return false;
  if (rol.includes("repartidor") || rol.includes("delivery") || rol === "driver") return false;
  return true;
}

exports.recordatorioCarritoAbandonado = onSchedule(
  {
    schedule: "every day 18:00",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    try {
      const ahoraMs = Date.now();
      const limiteMs = HORAS_CARRITO_ABANDONADO * 60 * 60 * 1000;

      const usuariosSnap = await admin.firestore().collection("usuarios").get();

      for (const userDoc of usuariosSnap.docs) {
        const userData = userDoc.data() || {};
        if (!esRolCliente(userData.rol || userData.role)) continue;

        const carritoSnap = await userDoc.ref.collection("carrito").get();
        if (carritoSnap.empty) continue;

        let masReciente = null;
        for (const item of carritoSnap.docs) {
          const updatedAt = (item.data() || {}).updatedAt?.toDate?.();
          if (updatedAt && (!masReciente || updatedAt > masReciente)) {
            masReciente = updatedAt;
          }
        }
        if (!masReciente || ahoraMs - masReciente.getTime() < limiteMs) continue;

        const ultimoAviso = userData.carritoRecordatorioEnviadoAt?.toDate?.();
        if (ultimoAviso && masReciente <= ultimoAviso) continue;

        const cantidad = carritoSnap.size;

        await sendPushToUserByUid({
          uidDestino: userDoc.id,
          title: "Tienes productos esperando en tu carrito",
          body:
            cantidad === 1
              ? "Dejaste 1 producto en tu carrito. Complétalo antes de que se agote."
              : `Dejaste ${cantidad} productos en tu carrito. Complétalo antes de que se agoten.`,
          data: {
            type: "recordatorio_carrito_abandonado",
            cantidad,
            target: "carrito",
          },
          androidChannelId: "reminders_channel",
          logContext: { trigger: "recordatorioCarritoAbandonado", uid: userDoc.id, cantidad },
        });

        await userDoc.ref.set(
          { carritoRecordatorioEnviadoAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true },
        );

        logger.info("Recordatorio de carrito abandonado enviado", {
          uid: userDoc.id,
          cantidad,
        });
      }
    } catch (error) {
      logger.error("Error en recordatorioCarritoAbandonado", error);
    }
  },
);

/* =========================================================
 * RECUPERACIÓN DE CONTRASEÑA
 *
 * Configura el correo remitente con variables de entorno:
 *   EMAIL_USER = tu_correo@gmail.com
 *   EMAIL_PASS = contraseña_de_aplicación_de_gmail
 *
 * Crea un archivo functions/.env con esas dos líneas,
 * o usa Firebase Secret Manager:
 *   firebase functions:secrets:set EMAIL_USER
 *   firebase functions:secrets:set EMAIL_PASS
 * =======================================================*/

function buildTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });
}

/* 5) ENVIAR CÓDIGO DE RECUPERACIÓN
 * Callable: enviarCodigoRecuperacion({ email })
 * Genera un código de 6 dígitos, lo guarda hasheado en
 * Firestore (password_reset_codes/{email}) y envía el email.
 * =======================================================*/
exports.enviarCodigoRecuperacion = onCall(
  { region: "us-central1" },
  async (request) => {
    const email = (request.data.email || "").trim().toLowerCase();

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Correo inválido");
    }

    // Verificar que el usuario existe en Firebase Auth
    try {
      await admin.auth().getUserByEmail(email);
    } catch (_) {
      throw new HttpsError(
        "not-found",
        "No existe una cuenta con este correo",
      );
    }

    // Generar código de 6 dígitos
    const code = String(Math.floor(100000 + Math.random() * 900000));
    const codeHash = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");
    const expiry = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 10 * 60 * 1000), // 10 minutos
    );

    await admin
      .firestore()
      .collection("password_reset_codes")
      .doc(email)
      .set({
        codeHash,
        expiry,
        used: false,
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Enviar email
    const transporter = buildTransporter();
    await transporter.sendMail({
      from: `"Quimisol" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: "Código de recuperación de contraseña",
      html: `
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;">
          <h2 style="color:#1DA1F2;">Recuperación de contraseña</h2>
          <p>Recibimos una solicitud para restablecer la contraseña de tu cuenta.</p>
          <p>Tu código de verificación es:</p>
          <div style="background:#EAF6F7;border-radius:12px;padding:28px;text-align:center;margin:20px 0;">
            <span style="font-size:44px;font-weight:bold;letter-spacing:14px;color:#1DA1F2;">${code}</span>
          </div>
          <p style="color:#666;">Este código expira en <strong>10 minutos</strong>.</p>
          <p style="color:#666;">Si no solicitaste este código, ignora este mensaje.</p>
        </div>
      `,
    });

    logger.info("Código de recuperación enviado", { email });
    return { success: true };
  },
);

/* 6) VERIFICAR CÓDIGO (sin consumirlo)
 * Callable: verificarCodigo({ email, code })
 * Verifica que el código sea correcto y no haya expirado.
 * Incrementa el contador de intentos fallidos si es incorrecto.
 * =======================================================*/
exports.verificarCodigo = onCall(
  { region: "us-central1" },
  async (request) => {
    const email = (request.data.email || "").trim().toLowerCase();
    const code = (request.data.code || "").trim();

    if (!email || !code) {
      throw new HttpsError("invalid-argument", "Datos incompletos");
    }

    const docRef = admin
      .firestore()
      .collection("password_reset_codes")
      .doc(email);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError("not-found", "Código inválido o expirado");
    }

    const { codeHash, expiry, used, attempts } = doc.data();

    if (used) {
      throw new HttpsError(
        "failed-precondition",
        "Este código ya fue utilizado",
      );
    }

    if (expiry.toDate() < new Date()) {
      throw new HttpsError("deadline-exceeded", "El código ha expirado");
    }

    if (attempts >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Demasiados intentos incorrectos. Solicita un nuevo código",
      );
    }

    const inputHash = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    if (codeHash !== inputHash) {
      await docRef.update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      const remaining = 5 - (attempts + 1);
      throw new HttpsError(
        "invalid-argument",
        `Código incorrecto. ${remaining} intento${remaining === 1 ? "" : "s"} restante${remaining === 1 ? "" : "s"}`,
      );
    }

    return { success: true };
  },
);

/* 7) VERIFICAR Y RESETEAR CONTRASEÑA
 * Callable: verificarYResetear({ email, code, newPassword })
 * Verifica el código, actualiza la contraseña via Admin SDK
 * y marca el código como usado.
 * =======================================================*/
exports.verificarYResetear = onCall(
  { region: "us-central1" },
  async (request) => {
    const email = (request.data.email || "").trim().toLowerCase();
    const code = (request.data.code || "").trim();
    const newPassword = request.data.newPassword || "";

    if (!email || !code || !newPassword) {
      throw new HttpsError("invalid-argument", "Datos incompletos");
    }

    // ✅ Defensa en profundidad: la app ya valida esto en el formulario,
    // pero igual lo exigimos aquí por si alguien llama la función directo.
    if (
      newPassword.length < 8 ||
      !/[A-Z]/.test(newPassword) ||
      !/[0-9]/.test(newPassword)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "La contraseña debe tener al menos 8 caracteres, una mayúscula y un número",
      );
    }

    const docRef = admin
      .firestore()
      .collection("password_reset_codes")
      .doc(email);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError("not-found", "Código inválido o expirado");
    }

    const { codeHash, expiry, used, attempts } = doc.data();

    if (used) {
      throw new HttpsError(
        "failed-precondition",
        "Este código ya fue utilizado",
      );
    }

    if (expiry.toDate() < new Date()) {
      throw new HttpsError("deadline-exceeded", "El código ha expirado");
    }

    if (attempts >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Demasiados intentos incorrectos. Solicita un nuevo código",
      );
    }

    const inputHash = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    if (codeHash !== inputHash) {
      await docRef.update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      throw new HttpsError("invalid-argument", "Código incorrecto");
    }

    // Marcar código como usado
    await docRef.update({ used: true });

    // Actualizar contraseña con Admin SDK
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });

    logger.info("Contraseña restablecida exitosamente", { email });
    return { success: true };
  },
);