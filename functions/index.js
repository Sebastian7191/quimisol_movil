const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Opcional: límite global de instancias (control de costo)
setGlobalOptions({ maxInstances: 10 });

/**
 * Trigger: cuando se crea un pedido en Firestore
 * Ajusta la ruta "pedidos/{pedidoId}" a tu colección real si cambia.
 */
exports.notificarNuevoPedido = onDocumentCreated(
  {
    document: "pedidos/{pedidoId}",
    region: "us-central1", // puedes cambiar región si quieres
  },
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) {
        logger.warn("No hay snapshot en el evento");
        return;
      }

      const pedido = snap.data();
      const pedidoId = event.params.pedidoId;

      // 🔧 AJUSTA ESTA PARTE A TU MODELO REAL
      // Ejemplos: uidTaxista, uidCliente, uidRepartidor, uidAdmin
      const uidDestino =
        pedido.uidTaxista || pedido.uidRepartidor || pedido.uidCliente;

      if (!uidDestino) {
        logger.warn("No se encontró uidDestino en el pedido", { pedidoId });
        return;
      }

      const userRef = admin.firestore().collection("usuarios").doc(uidDestino);
      const userSnap = await userRef.get();

      if (!userSnap.exists) {
        logger.warn("Usuario destino no existe", { uidDestino, pedidoId });
        return;
      }

      const userData = userSnap.data() || {};

      // Recomendado: guardar múltiples tokens por usuario
      const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];

      if (tokens.length === 0) {
        logger.warn("Usuario sin tokens FCM", { uidDestino, pedidoId });
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Nuevo pedido",
          body: "Tienes una nueva solicitud",
        },
        data: {
          type: "nuevo_pedido",
          pedidoId: String(pedidoId),
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      logger.info("Notificación enviada", {
        pedidoId,
        uidDestino,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      // Limpieza de tokens inválidos
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
          logger.error("Error enviando a token", {
            token: tokens[i],
            code,
            message: r.error?.message,
          });
        }
      });

      if (invalidTokens.length > 0) {
        const cleanedTokens = tokens.filter((t) => !invalidTokens.includes(t));
        await userRef.update({ fcmTokens: cleanedTokens });
        logger.info("Tokens inválidos eliminados", {
          uidDestino,
          invalidCount: invalidTokens.length,
        });
      }
    } catch (error) {
      logger.error("Error en notificarNuevoPedido", error);
    }
  }
);