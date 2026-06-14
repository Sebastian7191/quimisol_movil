const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const { Timestamp, FieldValue } = require("firebase-admin/firestore");

const { defineSecret } = require("firebase-functions/params");
const { genkit } = require("genkit");
const { googleAI } = require("@genkit-ai/google-genai");
const { z } = require("zod");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

function getAI() {
  return genkit({
    plugins: [
      googleAI({ apiKey: GEMINI_API_KEY.value() }),
    ],
  });
}

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

/* =========================================================
   Helpers
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

// ====== HELPERS PARA REPORTES ======

function normalizeEstado(v) {
  const s = (v ?? "").toString().trim().toLowerCase();
  const noAccents = s.normalize("NFD").replace(/[̀-ͯ]/g, "");
  if (noAccents.includes("pend")) return "pendiente";
  if (noAccents.includes("acept")) return "aceptado";
  if (noAccents.includes("camino")) return "en camino";
  if (noAccents.includes("entreg")) return "entregado";
  if (noAccents.includes("cancel")) return "cancelado";
  return noAccents;
}

function toDateOrNull(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === "function") return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function isoDay(d) {
  return startOfDay(d).toISOString().slice(0, 10);
}

function weekKeyMonday(dateObj) {
  const d = startOfDay(dateObj);
  const day = d.getDay();
  const diff = (day === 0 ? -6 : 1) - day;
  d.setDate(d.getDate() + diff);
  return isoDay(d);
}

function ewma(series, alpha = 0.5) {
  let s = null;
  for (const x of series) {
    const v = Number(x) || 0;
    s = s === null ? v : alpha * v + (1 - alpha) * s;
  }
  return s ?? 0;
}

function mean(arr) {
  if (!arr.length) return 0;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

function stddev(arr) {
  if (arr.length < 2) return 0;
  const m = mean(arr);
  const v = mean(arr.map((x) => (x - m) ** 2));
  return Math.sqrt(v);
}

function trendLabel(last2, prev2, threshold = 0.08) {
  if (prev2 <= 0 && last2 > 0) return "up";
  if (prev2 <= 0 && last2 <= 0) return "flat";
  const change = (last2 - prev2) / prev2;
  if (change > threshold) return "up";
  if (change < -threshold) return "down";
  return "flat";
}

function confidenceLabel(nonZeroWeeks, totalWeeks) {
  if (totalWeeks < 4) return "low";
  const ratio = totalWeeks === 0 ? 0 : nonZeroWeeks / totalWeeks;
  if (totalWeeks >= 10 && ratio >= 0.6) return "high";
  if (totalWeeks >= 6 && ratio >= 0.35) return "med";
  return "low";
}

/* =========================================================
 * 3) GENERAR REPORTE PREDICTIVO BAJO DEMANDA
 * Callable: generatePredictiveReportOnDemand
 * =======================================================*/

exports.generatePredictiveReportOnDemand = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const db = admin.firestore();

    // Permite acceso si está en la colección "admins" O si tiene rol superadmin en "usuarios"
    const [adminSnap, userSnap] = await Promise.all([
      db.collection("admins").doc(uid).get(),
      db.collection("usuarios").doc(uid).get(),
    ]);

    const userData = userSnap.exists ? (userSnap.data() || {}) : {};
    const rol = String(userData.rol || userData.role || "").trim().toLowerCase();

    if (!adminSnap.exists && rol !== "superadmin") {
      throw new HttpsError(
        "permission-denied",
        "Solo administradores pueden generar reportes.",
      );
    }

    const {
      from,
      to,
      horizonDays = 30,
      deliveredOnly = true,
      departamento = null,
      limitProducts = 30,
    } = request.data || {};

    const now = new Date();
    const toDate = toDateOrNull(to) || now;

    const reportFromDate =
      toDateOrNull(from) || new Date(toDate.getTime() - 7 * 24 * 60 * 60 * 1000);

    const historyWeeks = Number(request.data?.historyWeeks ?? 12);
    const historyDays = Math.max(7, historyWeeks * 7);
    const historyFromDate = new Date(toDate.getTime() - historyDays * 24 * 60 * 60 * 1000);

    const fromTS = Timestamp.fromDate(historyFromDate);
    const toTS = Timestamp.fromDate(toDate);

    logger.info("Generando reporte predictivo (on-demand)", {
      uid,
      rol,
      reportFrom: reportFromDate.toISOString(),
      from: historyFromDate.toISOString(),
      to: toDate.toISOString(),
      historyWeeks,
      horizonDays,
      deliveredOnly,
      departamento,
    });

    let q = db.collection("pedidos")
      .where("createdAt", ">=", fromTS)
      .where("createdAt", "<=", toTS);

    if (departamento) {
      q = q.where("ubicacion.departamento", "==", departamento);
    }

    const pedidosSnap = await q.get();

    const pedidos = [];
    for (const doc of pedidosSnap.docs) {
      const p = doc.data() || {};
      const estNorm = normalizeEstado(p.estado);

      if (deliveredOnly) {
        if (estNorm !== "entregado") continue;
      } else {
        if (estNorm === "cancelado") continue;
      }

      pedidos.push({ id: doc.id, ...p });
    }

    const productWeek = new Map();
    const productMeta = new Map();
    const productRecentUnits = new Map();

    for (const p of pedidos) {
      const created = toDateOrNull(p.createdAt);
      if (!created) continue;

      const wk = weekKeyMonday(created);
      const items = Array.isArray(p.items) ? p.items : [];

      for (const it of items) {
        const productId = it.productId || it.productID || it.idProducto || null;
        const qty = Number(it.qty ?? it.cantidad ?? 0) || 0;
        if (!productId || qty <= 0) continue;

        const name = (it.name ?? "").toString();
        const codigo = (p.codigo ?? "").toString();
        if (!productMeta.has(productId)) productMeta.set(productId, { name, codigo });

        if (!productWeek.has(productId)) productWeek.set(productId, new Map());
        const wkMap = productWeek.get(productId);
        wkMap.set(wk, (wkMap.get(wk) || 0) + qty);

        productRecentUnits.set(productId, (productRecentUnits.get(productId) || 0) + qty);
      }
    }

    if (productWeek.size === 0) {
      const reportRef = await db.collection("reports").add({
        type: "predictivo",
        createdAt: FieldValue.serverTimestamp(),
        range: { from: reportFromDate, to: toDate },
        historyRange: { from: historyFromDate, to: toDate },
        historyWeeks,
        horizonDays,
        filters: { departamento: departamento || null, deliveredOnly },
        overview: { productsAnalyzed: 0 },
        perProduct: [],
        ai: { summary: "", insights: [], risks: [], actions: [] },
      });

      return { ok: true, reportId: reportRef.id, empty: true };
    }

    const sortedByUnits = [...productRecentUnits.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, Math.max(1, Math.min(200, Number(limitProducts) || 30)));

    const selectedProductIds = sortedByUnits.map(([pid]) => pid);

    const productRefs = selectedProductIds.map((pid) => db.collection("productos").doc(pid));
    const productDocs = productRefs.length ? await db.getAll(...productRefs) : [];

    const stockByProduct = new Map();
    for (const doc of productDocs) {
      if (!doc.exists) continue;
      const d = doc.data() || {};
      const stock = Number(d.stock ?? 0) || 0;
      stockByProduct.set(doc.id, stock);
    }

    const perProduct = [];

    for (const pid of selectedProductIds) {
      const wkMap = productWeek.get(pid) || new Map();
      const weeks = [...wkMap.keys()].sort();
      const series = weeks.map((wk) => Number(wkMap.get(wk) || 0));

      const ewmaWeekly = ewma(series, 0.5);

      const forecastUnits7d = ewmaWeekly;
      const forecastUnitsHorizon = ewmaWeekly * (Number(horizonDays) / 7);

      const last2 = mean(series.slice(-2));
      const prev2 = mean(series.slice(-4, -2));
      const trend = trendLabel(last2, prev2);

      const nonZeroWeeks = series.filter((x) => x > 0).length;
      const confidence = confidenceLabel(nonZeroWeeks, series.length);

      const prev = series.slice(Math.max(0, series.length - 9), -1);
      const m = mean(prev);
      const s = stddev(prev);
      const last = series.length ? series[series.length - 1] : 0;
      const anomalies = [];
      if (prev.length >= 6 && s > 0) {
        if (last > m + 2 * s) anomalies.push({ type: "spike", week: weeks[weeks.length - 1], value: last });
        if (last < Math.max(0, m - 2 * s)) anomalies.push({ type: "drop", week: weeks[weeks.length - 1], value: last });
      }

      const stock = stockByProduct.get(pid) ?? 0;
      const avgDaily = forecastUnitsHorizon / Math.max(1, Number(horizonDays));
      const daysOfCover = avgDaily > 0 ? stock / avgDaily : null;

      const targetStock = Math.ceil(forecastUnitsHorizon * 1.1);
      const restockQtySuggestion = Math.max(0, targetStock - stock);

      let urgency = "low";
      if (daysOfCover !== null) {
        if (daysOfCover < 7) urgency = "high";
        else if (daysOfCover < 14) urgency = "med";
      }

      const meta = productMeta.get(pid) || { name: "", codigo: "" };

      perProduct.push({
        productId: pid,
        name: meta.name || null,
        codigo: meta.codigo || null,
        weeks,
        weeklyUnits: series,
        forecastUnits7d: Math.round(forecastUnits7d * 100) / 100,
        forecastUnitsHorizon: Math.round(forecastUnitsHorizon * 100) / 100,
        horizonDays: Number(horizonDays),
        trend,
        confidence,
        anomalies,
        stock,
        avgDaily: Math.round(avgDaily * 1000) / 1000,
        daysOfCover: daysOfCover === null ? null : Math.round(daysOfCover * 10) / 10,
        restockQtySuggestion,
        urgency,
      });
    }

    const productsAtRiskCount = perProduct.filter((p) => p.urgency === "high").length;
    const risingProductsCount = perProduct.filter((p) => p.trend === "up").length;
    const fallingProductsCount = perProduct.filter((p) => p.trend === "down").length;

    const overview = {
      productsAnalyzed: perProduct.length,
      productsAtRiskCount,
      risingProductsCount,
      fallingProductsCount,
    };

    const reportDoc = {
      type: "predictivo",
      createdAt: FieldValue.serverTimestamp(),
      range: { from: reportFromDate, to: toDate },
      historyRange: { from: historyFromDate, to: toDate },
      historyWeeks,
      horizonDays: Number(horizonDays),
      filters: { departamento: departamento || null, deliveredOnly: !!deliveredOnly },
      overview,
      perProduct,
      ai: { summary: "", insights: [], risks: [], actions: [] },
    };

    const reportRef = await db.collection("reports").add(reportDoc);

    logger.info("Reporte predictivo guardado", { reportId: reportRef.id });

    return {
      ok: true,
      reportId: reportRef.id,
      overview,
    };
  },
);

/* =========================================================
 * HELPERS PARA enrichPredictiveReportAI
 * =======================================================*/

function buildRelevantProducts(perProduct) {
  const list = Array.isArray(perProduct) ? perProduct : [];

  const urgent = list
    .filter((p) => p?.urgency === "high" || p?.urgency === "med")
    .sort((a, b) => {
      const aCover = Number(a?.daysOfCover ?? 999999);
      const bCover = Number(b?.daysOfCover ?? 999999);
      return aCover - bCover;
    })
    .slice(0, 3);

  const topForecast = [...list]
    .sort((a, b) => Number(b?.forecastUnits7d || 0) - Number(a?.forecastUnits7d || 0))
    .slice(0, 3);

  const anomalous = list
    .filter((p) => Array.isArray(p?.anomalies) && p.anomalies.length > 0)
    .sort((a, b) => (b?.anomalies?.length || 0) - (a?.anomalies?.length || 0))
    .slice(0, 2);

  const merged = [...urgent, ...topForecast, ...anomalous];

  const seen = new Set();
  const unique = [];
  for (const p of merged) {
    const id = String(p?.productId || "");
    if (!id || seen.has(id)) continue;
    seen.add(id);
    unique.push(p);
  }

  return unique.slice(0, 7);
}

function pickProductCompact(p) {
  return {
    name: (p?.name || p?.codigo || "Producto").toString().slice(0, 60),
    urgency: p?.urgency || "unknown",
    daysOfCover:
      p?.daysOfCover === null || p?.daysOfCover === undefined
        ? null
        : Number(p.daysOfCover),
    stock: Number(p?.stock || 0),
    forecastUnits7d: Number(p?.forecastUnits7d || 0),
    trend: p?.trend || "flat",
    confidence: p?.confidence || "low",
    restockQtySuggestion: Number(p?.restockQtySuggestion || 0),
    anomaliesCount: Array.isArray(p?.anomalies) ? p.anomalies.length : 0,
  };
}

/* =========================================================
 * 4) ENRIQUECER REPORTE CON IA (Gemini)
 * Trigger: reports/{reportId}
 * =======================================================*/

exports.enrichPredictiveReportAI = onDocumentCreated(
  {
    document: "reports/{reportId}",
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: [GEMINI_API_KEY],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const reportId = event.params.reportId;
    const report = snap.data() || {};
    if (report.type !== "predictivo") return;

    const db = admin.firestore();

    const aiPrev = report.ai || {};
    const prevStatus = String(aiPrev.status || "").trim();

    if (prevStatus === "done") return;
    if (prevStatus === "generating") return;

    await db.collection("reports").doc(reportId).set(
      {
        ai: {
          status: "generating",
          startedAt: FieldValue.serverTimestamp(),
          error: FieldValue.delete(),
        },
      },
      { merge: true },
    );

    const AiSchema = z.object({
      summary: z.string().min(80).max(900),
      insights: z.array(z.string().min(1)).min(2).max(5),
      risks: z.array(z.string().min(1)).min(1).max(4),
      actions: z.array(z.string().min(1)).min(2).max(6),
    });

    function clampArr(arr, max) {
      return Array.isArray(arr) ? arr.slice(0, max) : [];
    }

    function cleanText(s) {
      return String(s || "")
        .replace(/“|”/g, '"')
        .replace(/‘|’/g, "'")
        .replace(/\r/g, "")
        .trim();
    }

    function stripCodeFences(s) {
      let t = cleanText(s);
      t = t.replace(/^```(?:json)?\s*/i, "");
      t = t.replace(/```$/i, "");
      return t.trim();
    }

    function removeTrailingCommas(jsonLike) {
      return jsonLike.replace(/,\s*([}\]])/g, "$1");
    }

    function extractBestJsonCandidate(text) {
      const t0 = stripCodeFences(text);

      if (
        (t0.startsWith('"') && t0.endsWith('"')) ||
        (t0.startsWith("'") && t0.endsWith("'"))
      ) {
        try {
          const unquoted = JSON.parse(t0);
          return typeof unquoted === "string"
            ? unquoted
            : JSON.stringify(unquoted);
        } catch (_) {}
      }

      const first = t0.indexOf("{");
      const last = t0.lastIndexOf("}");
      if (first !== -1 && last !== -1 && last > first) {
        return t0.slice(first, last + 1);
      }

      return t0;
    }

    function robustJsonParse(text) {
      const candidate = extractBestJsonCandidate(text);
      const fixed = removeTrailingCommas(candidate);

      try {
        return { ok: true, value: JSON.parse(fixed), used: fixed };
      } catch (_) {}

      const m = fixed.match(/\{[\s\S]*\}/);
      if (m) {
        const inner = removeTrailingCommas(m[0]);
        try {
          return { ok: true, value: JSON.parse(inner), used: inner };
        } catch (_) {}
      }

      return { ok: false, value: null, used: fixed };
    }

    function coerceAiShape(obj) {
      const summary = cleanText(obj?.summary);
      const insights = clampArr(obj?.insights, 5).map(cleanText).filter(Boolean);
      const risks = clampArr(obj?.risks, 4).map(cleanText).filter(Boolean);
      const actions = clampArr(obj?.actions, 6).map(cleanText).filter(Boolean);
      return { summary, insights, risks, actions };
    }

    function extractSummaryFromTextFallback(s) {
      const t = String(s || "").trim();
      // Intenta extraer el valor de "summary" de un JSON parcial
      const m = t.match(/"summary"\s*:\s*"([\s\S]*?)(?:"|$)/);
      if (m && m[1]) return m[1].replace(/\\n/g, " ").trim();
      return t;
    }

    function makeFallbackSummaryReadable(text) {
      let s = cleanText(text || "");
      if (!s) return "";

      s = extractSummaryFromTextFallback(s);
      s = s.replace(/^"+/, "").replace(/"+$/, "").trim();

      const lastPunct = Math.max(
        s.lastIndexOf("."),
        s.lastIndexOf("!"),
        s.lastIndexOf("?"),
      );

      if (lastPunct >= 60) {
        s = s.slice(0, lastPunct + 1).trim();
        return s;
      }

      s = s.replace(/\s+(de los|con|para|y|e|que|del)\s*$/i, "").trim();

      if (s && !/[.!?]$/.test(s)) {
        s = `${s}.`;
      }

      return s.slice(0, 1200);
    }

    function countBy(arr, keyFn) {
      const out = {};
      for (const x of arr) {
        const k = String(keyFn(x));
        out[k] = (out[k] || 0) + 1;
      }
      return out;
    }

    function safeRange(r) {
      if (!r) return null;
      const from = r.from?.toDate ? r.from.toDate() : r.from;
      const to = r.to?.toDate ? r.to.toDate() : r.to;
      return {
        from: from ? new Date(from).toISOString() : null,
        to: to ? new Date(to).toISOString() : null,
      };
    }

    function looksTruncatedSummary(s) {
      const t = String(s || "").trim();
      if (!t) return true;
      if (t.length < 90) return true;
      if (!/[.!?]$/.test(t)) return true;
      if (/\bde\s+2$/.test(t) || /\bde\s+20$/.test(t) || /\bde\s+202$/.test(t)) return true;
      if (/(de los|con|para|y|e|que|del)\s*$/.test(t.toLowerCase())) return true;
      if (/[,:;]$/.test(t)) return true;
      return false;
    }

    function hasUsefulLists(insights, risks, actions) {
      return (
        (Array.isArray(insights) && insights.length > 0) ||
        (Array.isArray(risks) && risks.length > 0) ||
        (Array.isArray(actions) && actions.length > 0)
      );
    }

    function shouldAcceptResult(summary, insights, risks, actions) {
      return (
        !looksTruncatedSummary(summary) &&
        hasUsefulLists(insights, risks, actions)
      );
    }

    const overview = report.overview || {};
    const perProduct = Array.isArray(report.perProduct) ? report.perProduct : [];

    const relevantProducts = buildRelevantProducts(perProduct).map(pickProductCompact);

    const counts = {
      urgency: countBy(perProduct, (p) => p?.urgency || "unknown"),
      trend: countBy(perProduct, (p) => p?.trend || "unknown"),
      confidence: countBy(perProduct, (p) => p?.confidence || "unknown"),
      anomaliesTotal: perProduct.reduce(
        (acc, p) => acc + (Array.isArray(p?.anomalies) ? p.anomalies.length : 0),
        0,
      ),
    };

    const payload = {
      range: safeRange(report.range),
      historyWeeks: report.historyWeeks || null,
      horizonDays: report.horizonDays || null,
      overview,
      counts,
      products: relevantProducts,
    };

    const systemRules = [
      "Devuelve SOLO JSON válido, sin markdown.",
      'Formato: {"summary":"...","insights":["..."],"risks":["..."],"actions":["..."]}',
      "Usa solo los datos de entrada. No inventes cifras.",
      "Escribe en español claro.",
      "Si falta espacio, usa menos texto, pero no cortes frases y cierra el JSON.",
      "summary: 3-5 frases, claro y ejecutivo.",
      "insights: 3 items.",
      "risks: 2 items.",
      "actions: 4 items.",
      "Menciona productos por nombre cuando aplique.",
      "Si hay urgencia alta o poca cobertura, prioriza reposición.",
      "Si hay tendencia al alza y confianza baja, recomienda monitoreo cercano.",
    ].join("\n");

    const userPrompt = [
      "ENTRADA_JSON:",
      JSON.stringify(payload),
      "SALIDA_JSON:",
    ].join("\n");

    let raw = "";

    try {
      logger.info("AI enrich start", {
        reportId,
        productsSent: relevantProducts.length,
      });

      const ai = getAI();

      const genConfig = {
        temperature: 0.1,
        maxOutputTokens: 1400,
        responseMimeType: "application/json",
      };

      // Intento 1: schema
      let out = null;

      try {
        const resp1 = await ai.generate({
          model: googleAI.model("gemini-2.5-flash"),
          prompt: `${systemRules}\n\n${userPrompt}`,
          config: genConfig,
          output: { schema: AiSchema },
        });

        out = resp1.output || null;
        raw = cleanText(resp1.text || "");
      } catch (e1) {
        logger.warn("AI schema output failed; retrying with text parse", {
          reportId,
          err: String(e1?.message || e1),
        });
      }

      if (out) {
        const coerced = coerceAiShape(out);

        if (shouldAcceptResult(coerced.summary, coerced.insights, coerced.risks, coerced.actions)) {
          await db.collection("reports").doc(reportId).set(
            {
              ai: {
                status: "done",
                summary: coerced.summary,
                insights: coerced.insights,
                risks: coerced.risks,
                actions: coerced.actions,
                generatedAt: FieldValue.serverTimestamp(),
                model: "gemini-2.5-flash",
                raw: raw ? raw.slice(0, 2500) : FieldValue.delete(),
              },
            },
            { merge: true },
          );

          logger.info("AI enriched report OK (schema)", { reportId });
          return;
        }

        logger.warn("Schema output incompleto; retrying", {
          reportId,
          summaryLength: coerced.summary.length,
          insights: coerced.insights.length,
          risks: coerced.risks.length,
          actions: coerced.actions.length,
        });
      }

      // Intento 2: texto + parse robusto
      const resp2 = await ai.generate({
        model: googleAI.model("gemini-2.5-flash"),
        prompt: `${systemRules}\n\n${userPrompt}`,
        config: { ...genConfig, temperature: 0.0, maxOutputTokens: 1400 },
      });

      raw = cleanText(resp2.text || "");

      const parsed = robustJsonParse(raw);
      if (parsed.ok) {
        const validated = AiSchema.safeParse(coerceAiShape(parsed.value));

        if (validated.success) {
          const v = validated.data;

          if (shouldAcceptResult(v.summary, v.insights, v.risks, v.actions)) {
            await db.collection("reports").doc(reportId).set(
              {
                ai: {
                  status: "done",
                  summary: v.summary,
                  insights: v.insights.map(cleanText).filter(Boolean),
                  risks: v.risks.map(cleanText).filter(Boolean),
                  actions: v.actions.map(cleanText).filter(Boolean),
                  generatedAt: FieldValue.serverTimestamp(),
                  model: "gemini-2.5-flash",
                  raw: raw.slice(0, 2500),
                },
              },
              { merge: true },
            );

            logger.info("AI enriched report OK (robust parse)", { reportId });
            return;
          }
        }
      }

      // Intento 3: fallback corto
      const retryPromptShort = [
        "Devuelve SOLO JSON válido, sin markdown.",
        'Formato: {"summary":"...","actions":["..."]}',
        "Usa solo los datos de entrada.",
        "summary: 3-4 frases y DEBE terminar con punto (.).",
        "actions: 3-4 items.",
        "No cortes frases. Cierra el JSON.",
        "ENTRADA_JSON:",
        JSON.stringify(payload),
        "SALIDA_JSON:",
      ].join("\n");

      const resp3 = await ai.generate({
        model: googleAI.model("gemini-2.5-flash"),
        prompt: retryPromptShort,
        config: {
          temperature: 0.0,
          maxOutputTokens: 1200,
          responseMimeType: "application/json",
        },
      });

      raw = cleanText(resp3.text || "");

      const parsedShort = robustJsonParse(raw);
      if (parsedShort.ok && parsedShort.value && typeof parsedShort.value === "object") {
        const summary = cleanText(parsedShort.value.summary);
        const actions = Array.isArray(parsedShort.value.actions)
          ? parsedShort.value.actions.map((x) => cleanText(x)).filter(Boolean).slice(0, 6)
          : [];

        if (!looksTruncatedSummary(summary) && actions.length > 0) {
          await db.collection("reports").doc(reportId).set(
            {
              ai: {
                status: "done",
                summary,
                insights: [],
                risks: [],
                actions,
                generatedAt: FieldValue.serverTimestamp(),
                model: "gemini-2.5-flash",
                raw: raw.slice(0, 2500),
              },
            },
            { merge: true },
          );

          logger.info("AI enriched report OK (short fallback)", { reportId });
          return;
        }
      }

      // Fallback final
      const fallbackSummary = makeFallbackSummaryReadable(raw);

      await db.collection("reports").doc(reportId).set(
        {
          ai: {
            status: "done_text",
            summary: fallbackSummary,
            insights: [],
            risks: [],
            actions: [],
            generatedAt: FieldValue.serverTimestamp(),
            model: "gemini-2.5-flash",
            raw: raw.slice(0, 2500),
          },
        },
        { merge: true },
      );

      logger.warn("AI enriched report ended as done_text", { reportId });
    } catch (err) {
      const msg = String(err?.message || err);

      await db.collection("reports").doc(reportId).set(
        {
          ai: {
            status: "error",
            error: msg,
            raw: raw ? raw.slice(0, 1500) : FieldValue.delete(),
            generatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );

      logger.error("AI enrich failed", { reportId, err: msg });
    }
  },
);
