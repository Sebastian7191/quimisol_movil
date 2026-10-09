// Migración única: pedidos entregados/completados con el pago en pendiente
// (creados antes de exigir el cobro para poder entregar) pasan a "pagado".
//
// Uso (desde la carpeta functions):
//   node scripts/migrar_pagos_completados.js            -> solo lista (no cambia nada)
//   node scripts/migrar_pagos_completados.js --aplicar  -> aplica los cambios
//
// Requiere credenciales de Google con acceso al proyecto
// (gcloud auth application-default login).

const admin = require("firebase-admin");

admin.initializeApp({ projectId: "quimisol-4f159" });
const db = admin.firestore();

const APLICAR = process.argv.includes("--aplicar");

const ENTREGADOS = ["entregado", "entregada", "completado", "completada"];

function norm(v) {
  return String(v || "").trim().toLowerCase();
}

async function main() {
  const snap = await db.collection("pedidos").get();

  const pendientes = snap.docs.filter((d) => {
    const data = d.data() || {};
    const estado = norm(data.estado);
    const pago = norm(data.estado_pago || data.estadoPago);
    return ENTREGADOS.includes(estado) && pago !== "pagado";
  });

  console.log(`Pedidos revisados: ${snap.size}`);
  console.log(`Entregados con pago no pagado: ${pendientes.length}\n`);

  for (const d of pendientes) {
    const data = d.data();
    console.log(
      `  #${data.codigo || d.id}  estado=${data.estado}  ` +
        `pago=${data.estado_pago || data.estadoPago || "(vacío)"}  ` +
        `tipo=${data.tipo_pago || data.tipoPago || "?"}`,
    );
  }

  if (!APLICAR) {
    console.log("\nSolo lectura. Para aplicar: --aplicar");
    return;
  }

  // Lotes de hasta 400 escrituras (límite de Firestore: 500).
  let batch = db.batch();
  let enLote = 0;
  let total = 0;

  for (const d of pendientes) {
    const data = d.data();
    const cambios = {
      estado_pago: "pagado",
      // Marca para saber que vino de esta migración (y no notificar).
      pago_migrado: true,
    };
    batch.update(d.ref, cambios);
    enLote++;

    const uid = String(data.uid || "").trim();
    if (uid) {
      batch.set(
        db.collection("usuarios").doc(uid).collection("pedidos").doc(d.id),
        cambios,
        { merge: true },
      );
      enLote++;
    }

    total++;
    if (enLote >= 400) {
      await batch.commit();
      batch = db.batch();
      enLote = 0;
    }
  }
  if (enLote > 0) await batch.commit();

  console.log(`\nActualizados: ${total} pedidos.`);
}

main().catch((e) => {
  console.error("Error:", e.message || e);
  process.exit(1);
});
