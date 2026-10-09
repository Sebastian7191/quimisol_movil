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

      // Pedidos viejos corregidos por migración: no avisar al cliente.
      if (afterData.pago_migrado === true && beforeData.pago_migrado !== true) {
        logger.info("Pago marcado por migración, no se envía push", { pedidoId });
        return;
      }

      if (estadoPagoDespues !== "pagado") {
        logger.info("Cambio de estado_pago no requiere push en esta función", {
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

      const title = "Pago aceptado";
      const body = codigoPedido
        ? `Tu pedido ${codigoPedido} fue aceptado. Toca aquí para ver los detalles.`
        : "Tu pedido fue aceptado. Toca aquí para ver los detalles.";
      const type = "pedido_pago_aceptado";

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
 * 11) NOTIFICAR AL CLIENTE CUANDO SU PEDIDO ESTÁ EN CAMINO
 * Trigger: pedidos/{pedidoId} — cuando estado cambia a "En curso"
 * =======================================================*/

exports.notificarPedidoEnCamino = onDocumentUpdated(
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

      const estadoAntes = norm(beforeData.estado);
      const estadoDespues = norm(afterData.estado);

      const estadosEnCamino = ["en_curso", "en curso", "encurso", "en_camino", "en camino"];

      if (estadosEnCamino.includes(estadoAntes) || !estadosEnCamino.includes(estadoDespues)) {
        return;
      }

      const uidCliente = String(
        afterData.uid ||
          afterData.clienteUid ||
          afterData.userUid ||
          afterData.usuarioUid ||
          afterData.uidCliente ||
          afterData.createdBy ||
          "",
      ).trim();

      if (!uidCliente) {
        logger.warn("notificarPedidoEnCamino: pedido sin uid del cliente", { pedidoId });
        return;
      }

      const codigoPedido = String(afterData.codigo || afterData.codigoPedido || "").trim();
      const repartidor = String(
        afterData.repartidorNombre || afterData.nombreRepartidor || afterData.repartidorName || "",
      ).trim();

      await sendPushToUserByUid({
        uidDestino: uidCliente,
        title: "¡Tu pedido está en camino! 🚚",
        body: codigoPedido
          ? (repartidor
              ? `Tu pedido #${codigoPedido} está en camino con ${repartidor}. Prepárate para recibirlo.`
              : `Tu pedido #${codigoPedido} está en camino. Prepárate para recibirlo.`)
          : "Tu pedido está en camino. Prepárate para recibirlo.",
        data: {
          type: "pedido_en_camino",
          pedidoId,
          codigo: codigoPedido,
          estado: "En curso",
          target: "detalle_pedido",
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarPedidoEnCamino",
          pedidoId,
          uidCliente,
          codigoPedido,
          estadoAntes,
        },
      });

      logger.info("Push de pedido en camino enviada", { pedidoId, uidCliente, codigoPedido });
    } catch (error) {
      logger.error("Error en notificarPedidoEnCamino", error);
    }
  },
);

/* =========================================================
 * 11b) NOTIFICAR AL CLIENTE CUANDO SU PEDIDO ES ACEPTADO
 * Trigger: pedidos/{pedidoId} — cuando estado cambia a "aceptado".
 * Incluye la fecha de entrega programada (fecha_envio) y el
 * repartidor si el admin ya los asignó.
 * =======================================================*/

// "lunes 05/10 a las 14:36" en hora de Bolivia; "" si no hay fecha.
function formatFechaEntrega(ts) {
  const d = ts?.toDate?.();
  if (!d) return "";

  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("es-BO", {
      timeZone: "America/La_Paz",
      weekday: "long",
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    })
      .formatToParts(d)
      .map((p) => [p.type, p.value]),
  );

  return `${parts.weekday} ${parts.day}/${parts.month} a las ${parts.hour}:${parts.minute}`;
}

exports.notificarPedidoAceptado = onDocumentUpdated(
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

      const estadoAntes = norm(beforeData.estado);
      const estadoDespues = norm(afterData.estado);

      const estadosAceptado = ["aceptado", "aceptada"];

      if (estadosAceptado.includes(estadoAntes) || !estadosAceptado.includes(estadoDespues)) {
        return;
      }

      const uidCliente = String(
        afterData.uid ||
          afterData.clienteUid ||
          afterData.userUid ||
          afterData.usuarioUid ||
          afterData.uidCliente ||
          afterData.createdBy ||
          "",
      ).trim();

      if (!uidCliente) {
        logger.warn("notificarPedidoAceptado: pedido sin uid del cliente", { pedidoId });
        return;
      }

      const codigoPedido = String(afterData.codigo || afterData.codigoPedido || "").trim();
      const repartidor = String(
        afterData.repartidorNombre ||
          afterData.repartidor_nombre ||
          afterData.nombreRepartidor ||
          afterData.repartidorName ||
          "",
      ).trim();
      const fechaEntrega = formatFechaEntrega(afterData.fecha_envio);

      const pedidoTxt = codigoPedido ? `Tu pedido #${codigoPedido}` : "Tu pedido";
      let body = fechaEntrega
        ? `${pedidoTxt} fue aceptado y se entregará el ${fechaEntrega}.`
        : `${pedidoTxt} fue aceptado. Pronto te confirmaremos la fecha de entrega.`;
      if (repartidor) body += ` Te lo llevará ${repartidor}.`;

      await sendPushToUserByUid({
        uidDestino: uidCliente,
        title: "¡Tu pedido fue aceptado! ✅",
        body,
        data: {
          type: "pedido_aceptado",
          pedidoId,
          codigo: codigoPedido,
          estado: "Aceptado",
          fechaEntrega,
          target: "detalle_pedido",
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarPedidoAceptado",
          pedidoId,
          uidCliente,
          codigoPedido,
          estadoAntes,
        },
      });

      logger.info("Push de pedido aceptado enviada", { pedidoId, uidCliente, codigoPedido });
    } catch (error) {
      logger.error("Error en notificarPedidoAceptado", error);
    }
  },
);

/* =========================================================
 * 11) NOTIFICAR AL CLIENTE CUANDO SU COMPROBANTE ES RECHAZADO
 * Trigger: pedidos/{pedidoId} — cuando estado_pago cambia a "rechazado"
 * =======================================================*/

exports.notificarPagoRechazado = onDocumentUpdated(
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

      const estadoPagoAntes = norm(beforeData.estado_pago || beforeData.estadoPago);
      const estadoPagoDespues = norm(afterData.estado_pago || afterData.estadoPago);

      // Solo actuar cuando cambia A "rechazado" (no si ya estaba rechazado)
      if (estadoPagoAntes === "rechazado" || estadoPagoDespues !== "rechazado") {
        return;
      }

      const uidCliente = String(
        afterData.uid ||
          afterData.clienteUid ||
          afterData.userUid ||
          afterData.usuarioUid ||
          afterData.uidCliente ||
          afterData.createdBy ||
          "",
      ).trim();

      if (!uidCliente) {
        logger.warn("notificarPagoRechazado: pedido sin uid del cliente", { pedidoId });
        return;
      }

      const codigoPedido = String(afterData.codigo || afterData.codigoPedido || "").trim();

      // Plazo para volver a pagar; si vence, cancelarPedidosPagoVencido
      // cancela el pedido.
      const limite = admin.firestore.Timestamp.fromMillis(
        Date.now() + DIAS_LIMITE_PAGO_RECHAZADO * 24 * 60 * 60 * 1000,
      );
      const limiteTexto = formatFechaEntrega(limite);

      const db = admin.firestore();
      const batch = db.batch();
      batch.set(
        db.collection("pedidos").doc(pedidoId),
        { fecha_limite_pago: limite },
        { merge: true },
      );
      batch.set(
        db.collection("usuarios").doc(uidCliente).collection("pedidos").doc(pedidoId),
        { fecha_limite_pago: limite },
        { merge: true },
      );
      await batch.commit();

      const pedidoTxt = codigoPedido ? `del pedido #${codigoPedido}` : "de tu pedido";

      await sendPushToUserByUid({
        uidDestino: uidCliente,
        title: "Comprobante de pago rechazado",
        body:
          `El comprobante ${pedidoTxt} fue rechazado. Tienes hasta el ${limiteTexto} ` +
          "para pagar y subir un nuevo comprobante; si no, el pedido se cancelará.",
        data: {
          type: "pedido_pago_rechazado",
          pedidoId,
          codigo: codigoPedido,
          estadoPago: "rechazado",
          fechaLimitePago: limiteTexto,
          target: "detalle_pedido",
        },
        androidChannelId: "orders_channel",
        logContext: {
          trigger: "notificarPagoRechazado",
          pedidoId,
          uidCliente,
          codigoPedido,
          estadoPagoAntes,
        },
      });

      logger.info("Push de pago rechazado enviada", {
        pedidoId,
        uidCliente,
        codigoPedido,
        limite: limiteTexto,
      });
    } catch (error) {
      logger.error("Error en notificarPagoRechazado", error);
    }
  },
);

/* =========================================================
 * 11c) CANCELAR PEDIDOS CON PAGO RECHAZADO Y PLAZO VENCIDO
 * Trigger: programado, cada hora.
 *
 * Cuando el admin rechaza un comprobante, notificarPagoRechazado
 * guarda fecha_limite_pago. Si vence y el pago sigue "rechazado"
 * (el cliente no subió otro comprobante), el pedido se cancela,
 * se devuelve el stock reservado y se avisa al cliente.
 * =======================================================*/

const DIAS_LIMITE_PAGO_RECHAZADO = 2;

exports.cancelarPedidosPagoVencido = onSchedule(
  {
    schedule: "every 60 minutes",
    region: "us-central1",
    timeZone: "America/La_Paz",
  },
  async () => {
    const db = admin.firestore();
    const ahora = admin.firestore.Timestamp.now();

    let vencidos;
    try {
      vencidos = await db
        .collection("pedidos")
        .where("fecha_limite_pago", "<=", ahora)
        .get();
    } catch (error) {
      logger.error("cancelarPedidosPagoVencido: error consultando pedidos", error);
      return;
    }

    for (const doc of vencidos.docs) {
      const pedidoId = doc.id;
      try {
        // Transacción: se vuelve a leer el pedido por si el cliente subió
        // un comprobante justo ahora.
        const cancelado = await db.runTransaction(async (tx) => {
          const pedidoRef = db.collection("pedidos").doc(pedidoId);
          const snap = await tx.get(pedidoRef);
          if (!snap.exists) return null;

          const data = snap.data() || {};
          const estado = norm(data.estado);
          const estadoPago = norm(data.estado_pago || data.estadoPago);

          if (
            estadoPago !== "rechazado" ||
            ["cancelado", "cancelada", "entregado", "completado"].includes(estado)
          ) {
            // Ya no aplica: solo se limpia el plazo.
            tx.update(pedidoRef, {
              fecha_limite_pago: admin.firestore.FieldValue.delete(),
            });
            return null;
          }

          const items = Array.isArray(data.items) ? data.items : [];
          const productRefs = items
            .filter((it) => it && it.productId && Number(it.qty) > 0)
            .map((it) => ({
              ref: db.collection("productos").doc(String(it.productId)),
              qty: Number(it.qty),
            }));
          const productSnaps = await Promise.all(
            productRefs.map((p) => tx.get(p.ref)),
          );

          const uidCliente = String(data.uid || data.clienteUid || "").trim();
          const cambios = {
            estado: "Cancelado",
            motivo_cancelacion: "Pago no realizado dentro del plazo",
            cancelado_automaticamente: true,
            // Desde aquí corren las 48 h del cliente para hablar con soporte.
            canceladoAt: admin.firestore.FieldValue.serverTimestamp(),
            fecha_limite_pago: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          tx.update(pedidoRef, cambios);
          if (uidCliente) {
            tx.set(
              db.collection("usuarios").doc(uidCliente).collection("pedidos").doc(pedidoId),
              cambios,
              { merge: true },
            );
          }

          // Devolver al inventario lo que el pedido tenía reservado.
          productSnaps.forEach((ps, i) => {
            if (!ps.exists) return;
            tx.update(productRefs[i].ref, {
              stock: admin.firestore.FieldValue.increment(productRefs[i].qty),
            });
          });

          return {
            uidCliente,
            codigoPedido: String(data.codigo || data.codigoPedido || "").trim(),
          };
        });

        if (!cancelado) continue;

        const { uidCliente, codigoPedido } = cancelado;
        logger.info("Pedido cancelado por pago vencido", { pedidoId, codigoPedido });

        if (!uidCliente) continue;

        await sendPushToUserByUid({
          uidDestino: uidCliente,
          title: "Pedido cancelado",
          body: codigoPedido
            ? `Tu pedido #${codigoPedido} fue cancelado porque no recibimos un nuevo comprobante de pago a tiempo.`
            : "Tu pedido fue cancelado porque no recibimos un nuevo comprobante de pago a tiempo.",
          data: {
            type: "pedido_cancelado",
            pedidoId,
            codigo: codigoPedido,
            estado: "Cancelado",
            target: "detalle_pedido",
          },
          androidChannelId: "orders_channel",
          logContext: {
            trigger: "cancelarPedidosPagoVencido",
            pedidoId,
            uidCliente,
            codigoPedido,
          },
        });
      } catch (error) {
        logger.error("cancelarPedidosPagoVencido: error con pedido", {
          pedidoId,
          error: String(error),
        });
      }
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

/* =========================================================
 * 8) CREAR PEDIDO (checkout atómico)
 * Callable: crearPedido({ ubicacion, tipoPago, estadoPago,
 *   comprobanteUrl, comprobanteNombre, qrImageUrl, qrDescargaUrl,
 *   observacionPago })
 *
 * Valida y descuenta el stock de cada producto del carrito y crea
 * el pedido dentro de una sola transacción de Firestore. Esto evita
 * que dos usuarios compren la última unidad de un producto a la vez:
 * Firestore usa optimistic concurrency, así que si dos transacciones
 * leen el mismo doc de producto, solo la primera en hacer commit gana;
 * la otra se reintenta automáticamente, relee el stock ya actualizado
 * y falla la validación antes de escribir nada.
 * =======================================================*/
/**
 * Normaliza un departamento para compararlo: sin espacios extra, en
 * minusculas y sin tildes, porque los nombres se cargan a mano desde el
 * panel admin y pueden venir con o sin acento ("Potosi" / "Potosí").
 *
 * @param {string} v Nombre del departamento.
 * @return {string} Nombre normalizado.
 */
function normalizaDepto(v) {
  return String(v || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ");
}

exports.crearPedido = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }

  const data = request.data || {};
  const ubicacion = data.ubicacion;
  if (!ubicacion || !ubicacion.departamento || !ubicacion.direccion) {
    throw new HttpsError("invalid-argument", "Ubicación de entrega inválida");
  }

  const tipoPago = String(data.tipoPago || "efectivo");
  const estadoPago = String(data.estadoPago || "pendiente");
  const comprobanteUrl = data.comprobanteUrl || null;
  const comprobanteNombre = data.comprobanteNombre || null;
  const qrImageUrl = data.qrImageUrl || null;
  const qrDescargaUrl = data.qrDescargaUrl || null;
  const observacionPago = data.observacionPago || null;

  const db = admin.firestore();
  const cartCollRef = db.collection("usuarios").doc(uid).collection("carrito");
  const pedidoDoc = db.collection("pedidos").doc();
  const userIndexDoc = db
    .collection("usuarios")
    .doc(uid)
    .collection("pedidos")
    .doc(pedidoDoc.id);

  const code = String(Math.floor(100000 + Math.random() * 900000));

  const result = await db.runTransaction(async (tx) => {
    const cartSnap = await tx.get(cartCollRef);
    if (cartSnap.empty) {
      throw new HttpsError("failed-precondition", "El carrito está vacío");
    }

    const productRefs = cartSnap.docs.map((d) =>
      db.collection("productos").doc(d.id),
    );
    const productSnaps = await Promise.all(
      productRefs.map((ref) => tx.get(ref)),
    );

    const items = [];
    let totalProductos = 0;

    for (let i = 0; i < cartSnap.docs.length; i++) {
      const cartData = cartSnap.docs[i].data() || {};
      const productSnap = productSnaps[i];

      const name = String(cartData.name || "");
      const price =
        typeof cartData.price === "number"
          ? cartData.price
          : Number(cartData.price) || 0;
      const qty =
        typeof cartData.qty === "number" && cartData.qty > 0
          ? cartData.qty
          : Number(cartData.qty) || 1;
      const imageUrl = String(cartData.imageUrl || "");

      if (!productSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          `"${name}" ya no está disponible`,
        );
      }

      const stock = Number(productSnap.data().stock ?? 0);
      if (stock < qty) {
        throw new HttpsError(
          "failed-precondition",
          stock <= 0
            ? `"${name}" se quedó sin stock`
            : `Solo quedan ${stock} unidad${stock === 1 ? "" : "es"} de "${name}"`,
        );
      }

      items.push({
        productId: cartSnap.docs[i].id,
        name,
        price,
        qty,
        imageUrl,
        subtotal: price * qty,
      });
      totalProductos += price * qty;
    }

    // Un pedido se despacha desde un solo almacen, asi que todos los
    // productos del carrito tienen que pertenecer al mismo departamento.
    // Se valida aqui (y no solo en la app) porque es la unica capa que el
    // cliente no puede saltarse.
    const almacenIds = [
      ...new Set(
        productSnaps
          .map((snap) => String(snap.data().almacenId || "").trim())
          .filter((id) => id !== ""),
      ),
    ];

    const almacenSnaps = await Promise.all(
      almacenIds.map((id) => tx.get(db.collection("almacenes").doc(id))),
    );

    // Se deduplica por nombre normalizado (no por texto exacto) para que
    // "Potosi" y "Potosí" no cuenten como dos departamentos distintos.
    const deptosPorClave = new Map();
    for (const snap of almacenSnaps) {
      if (!snap.exists) continue;

      const dep = String(snap.data().departamento || "").trim();
      if (dep === "") continue;

      const clave = normalizaDepto(dep);
      if (!deptosPorClave.has(clave)) deptosPorClave.set(clave, dep);
    }

    const deptosAlmacen = [...deptosPorClave.values()];

    if (deptosAlmacen.length > 1) {
      throw new HttpsError(
        "failed-precondition",
        `No se puede combinar productos de ${deptosAlmacen.join(" y ")} ` +
          "en un mismo pedido. Deja solo los productos de un departamento.",
      );
    }

    if (
      deptosAlmacen.length === 1 &&
      normalizaDepto(deptosAlmacen[0]) !== normalizaDepto(ubicacion.departamento)
    ) {
      throw new HttpsError(
        "failed-precondition",
        `La dirección de entrega debe estar en ${deptosAlmacen[0]}, ` +
          "que es el departamento del almacén de estos productos.",
      );
    }

    const costoEnvio = 0.0;
    const totalFinal = totalProductos + costoEnvio;

    const payloadBase = {
      codigo: code,
      estado: "pendiente",
      tipo_pago: tipoPago,
      estado_pago: estadoPago,
      departamento: ubicacion.departamento,
      direccion: ubicacion.direccion,
      total: totalFinal,
      subtotal: totalProductos,
      costo_envio: costoEnvio,
      fecha_entrega: null,
      conteoItems: items.length,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      uid,
      comprobante_url: comprobanteUrl,
      comprobante_nombre: comprobanteNombre,
      qr_image_url: qrImageUrl,
      observacion_pago: observacionPago,
    };

    for (let i = 0; i < productRefs.length; i++) {
      tx.update(productRefs[i], {
        stock: admin.firestore.FieldValue.increment(-items[i].qty),
      });
    }

    tx.set(pedidoDoc, {
      ...payloadBase,
      items,
      ubicacion,
      qr_descarga_url: qrDescargaUrl,
    });
    tx.set(userIndexDoc, payloadBase);

    for (const d of cartSnap.docs) {
      tx.delete(d.ref);
    }

    return { pedidoId: pedidoDoc.id, code };
  });

  logger.info("Pedido creado", { pedidoId: result.pedidoId, uid });
  return result;
});