// functions/index.js

const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

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

  if (!tokens.length) {
    logger.warn("Usuario sin fcmTokens", { uidDestino, ...logContext });
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