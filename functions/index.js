// functions/index.js

const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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

  // ✅ Limpieza de tokens inválidos
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

/* =========================================================
 * 1) NOTIFICAR NUEVO PEDIDO
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

      // 🔧 Ajusta según tu modelo real
      const uidDestino =
        pedido.uidTaxista || pedido.uidRepartidor || pedido.uidCliente;

      if (!uidDestino) {
        logger.warn("No se encontró uidDestino en pedido", { pedidoId });
        return;
      }

      await sendPushToUserByUid({
        uidDestino,
        title: "Nuevo pedido",
        body: "Tienes una nueva solicitud",
        data: {
          type: "nuevo_pedido",
          pedidoId,
        },
        androidChannelId: "orders_channel",
        logContext: { trigger: "notificarNuevoPedido", pedidoId },
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

      const senderRole = (msg.senderRole || "").toString().trim(); // support | client | system
      const senderName = (msg.senderName || "").toString().trim() || "Soporte";
      const type = (msg.type || "text").toString().trim();
      const text = (msg.text || "").toString().trim();

      // ❌ No enviar push por mensajes del sistema
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

      // ✅ Flags de presencia (los que ya estás guardando desde Flutter)
      const clientInSupportChatPage = chat.clientInSupportChatPage === true;
      const supportInChatPage = chat.supportInChatPage === true;

      let uidDestino = "";
      let title = "";
      let body = "";

      if (senderRole === "support") {
        // Soporte escribe -> notificar cliente
        uidDestino = clientUid;

        // ✅ Si el cliente está dentro del chat, no mandes push
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
        // Cliente escribe -> notificar asesor asignado
        uidDestino = supportUid;

        // ✅ Si el asesor está dentro del chat, no mandes push
        if (supportInChatPage) {
          logger.info("Soporte está en el chat, no se envía push", {
            chatId,
            messageId,
            supportUid,
          });
          return;
        }

        // ✅ WhatsApp style:
        //   - título: nombre del cliente
        //   - body: el mensaje (o 📷 Imagen)
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