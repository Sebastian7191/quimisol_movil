// lib/features/pedidos/controllers/detalle_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/detalle_data.dart';

class PedidoDetalleController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtiene los datos completos del pedido tipados
  Future<PedidoDetalleData> fetchPedido(String pedidoId) async {
    final doc = await _firestore.collection('pedidos').doc(pedidoId).get();
    return PedidoDetalleData.fromDoc(doc);
  }

  // Obtiene cliente info (nombre, email)
  Future<Map<String, String>> fetchClienteInfo(String clienteUid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(clienteUid).get();
      final data = doc.data() ?? {};
      return {
        'nombre': (data['name'] ?? data['nombre'] ?? 'Cliente').toString(),
        'email': (data['email'] ?? '').toString(),
      };
    } catch (_) {
      return {'nombre': 'Cliente', 'email': ''};
    }
  }

  // ✅ Obtiene repartidores (colección raíz /repartidores) filtrando por almacenId
  // - Si hay almacenId: where almacenId == X
  // - Si NO hay: busca almacenes por departamento, luego whereIn(almacenId in [...]) en chunks de 10
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchRepartidores({
    String? departamento,
    String? almacenId,
  }) async {
    final alm = (almacenId ?? '').trim();
    if (alm.isNotEmpty) {
      final q = await _firestore
          .collection('repartidores')
          .where('almacenId', isEqualTo: alm)
          .get();
      return q.docs;
    }

    final dep = (departamento ?? '').trim();
    if (dep.isEmpty) return [];

    final almacenesSnap = await _firestore
        .collection('almacenes')
        .where('departamento', isEqualTo: dep)
        .get();

    final ids = almacenesSnap.docs.map((d) => d.id).toList();
    if (ids.isEmpty) return [];

    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final chunk in _chunks(ids, 10)) {
      final q = await _firestore
          .collection('repartidores')
          .where('almacenId', whereIn: chunk)
          .get();
      out.addAll(q.docs);
    }

    return out;
  }

  // Guarda cambios al pedido
  Future<void> guardarCambios({
    required String pedidoId,
    required String nuevoEstado,
    DateTime? fechaEnvio,
    double? costoEnvio,
    String? repartidorUid,
    String? repartidorNombre,
  }) async {
    final data = <String, dynamic>{};

    data['estado'] = nuevoEstado;

    // fecha envio
    data['fecha_envio'] = fechaEnvio == null ? null : Timestamp.fromDate(fechaEnvio);

    // costo envio
    if (costoEnvio != null) {
      data['costo_envio'] = costoEnvio;
    }

    // ✅ si no hay repartidor => borra asignación
    final repUid = (repartidorUid ?? '').trim();
    if (repUid.isEmpty) {
      data['repartidorUid'] = FieldValue.delete();
      data['repartidorNombre'] = FieldValue.delete();
    } else {
      data['repartidorUid'] = repUid;
      final repNom = (repartidorNombre ?? '').trim();
      if (repNom.isNotEmpty) data['repartidorNombre'] = repNom;
    }

    data['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('pedidos').doc(pedidoId).update(data);
  }
}

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (int i = 0; i < list.length; i += size) {
    final end = (i + size > list.length) ? list.length : i + size;
    yield list.sublist(i, end);
  }
}
