import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/detalle_data.dart';

class PedidoDetalleController {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  Future<PedidoDetalleData> fetchPedido(String pedidoId) async {
    final doc = await _fire.collection('pedidos').doc(pedidoId).get();
    if (!doc.exists) {
      throw Exception('No existe el pedido.');
    }
    return PedidoDetalleData.fromDoc(
      doc as DocumentSnapshot<Map<String, dynamic>>,
    );
  }

  Future<Map<String, String>> fetchClienteInfo(String uid) async {
    if (uid.trim().isEmpty) {
      return {'nombre': '—', 'email': '—'};
    }

    final doc = await _fire.collection('usuarios').doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    final nombre =
        (data['nombre'] ??
                data['name'] ??
                data['displayName'] ??
                data['fullName'] ??
                '—')
            .toString()
            .trim();

    final email = (data['email'] ?? '—').toString().trim();

    return {
      'nombre': nombre.isEmpty ? '—' : nombre,
      'email': email.isEmpty ? '—' : email,
    };
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchRepartidores({
    required String departamento,
    required String almacenId,
  }) async {
    final dep = departamento.trim().toLowerCase();
    final alm = almacenId.trim();

    final snap = await _fire.collection('usuarios').get();

    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final d in snap.docs) {
      final data = d.data();

      final rol = (data['rol'] ?? data['role'] ?? '').toString().toLowerCase();
      final activo = (data['activo'] ?? data['isActive'] ?? true) == true;

      if (!activo) continue;

      final isRepartidor =
          rol.contains('repartidor') ||
          rol.contains('delivery') ||
          rol == 'driver';

      if (!isRepartidor) continue;

      final depUser = (data['departamento'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (dep.isNotEmpty && depUser.isNotEmpty && depUser != dep) {
        continue;
      }

      final almacenUser =
          (data['almacenId'] ??
                  data['almacen_id'] ??
                  data['almacenUid'] ??
                  data['almacen_uid'] ??
                  '')
              .toString()
              .trim();

      if (alm.isNotEmpty && almacenUser.isNotEmpty && almacenUser != alm) {
        continue;
      }

      out.add(d);
    }

    return out;
  }

  Future<void> guardarCambios({
    required String pedidoId,
    required String nuevoEstado,
    required String nuevoEstadoPago,
    String? motivoRechazoPago,
    DateTime? fechaEnvio,
    required double costoEnvio,
    String? repartidorUid,
    String? repartidorNombre,
  }) async {
    final pedidoRef = _fire.collection('pedidos').doc(pedidoId);
    final pedidoSnap = await pedidoRef.get();

    if (!pedidoSnap.exists) {
      throw Exception('El pedido no existe.');
    }

    final data = pedidoSnap.data() ?? <String, dynamic>{};
    final uid = (data['uid'] ?? '').toString().trim();

    final subtotalRaw = data['subtotal'];
    final subtotal = subtotalRaw is num
        ? subtotalRaw.toDouble()
        : double.tryParse((subtotalRaw ?? '0').toString()) ?? 0.0;

    final totalFinal = subtotal + costoEnvio;

    final estadoPagoFinal = nuevoEstadoPago.trim().toLowerCase();
    final estadoFinal =
        estadoPagoFinal == 'rechazado' ? 'pendiente' : nuevoEstado;
    final motivoFinal =
        estadoPagoFinal == 'rechazado'
            ? (motivoRechazoPago ?? '').trim()
            : '';

    final payload = <String, dynamic>{
      'estado': estadoFinal,
      'estado_pago': estadoPagoFinal,
      'motivo_rechazo_pago': motivoFinal,
      'costo_envio': costoEnvio,
      'total': totalFinal,
      'updatedAt': FieldValue.serverTimestamp(),
      'repartidorUid': repartidorUid,
      'repartidorNombre': repartidorNombre,
      'repartidor_uid': repartidorUid,
      'repartidor_nombre': repartidorNombre,
    };

    if (fechaEnvio != null) {
      payload['fecha_envio'] = Timestamp.fromDate(fechaEnvio);
    } else {
      payload['fecha_envio'] = null;
    }

    final batch = _fire.batch();
    batch.set(pedidoRef, payload, SetOptions(merge: true));

    if (uid.isNotEmpty) {
      final userPedidoRef = _fire
          .collection('usuarios')
          .doc(uid)
          .collection('pedidos')
          .doc(pedidoId);

      batch.set(
        userPedidoRef,
        {
          'estado': estadoFinal,
          'estado_pago': estadoPagoFinal,
          'motivo_rechazo_pago': motivoFinal,
          'costo_envio': costoEnvio,
          'total': totalFinal,
          'updatedAt': FieldValue.serverTimestamp(),
          'repartidorUid': repartidorUid,
          'repartidorNombre': repartidorNombre,
          'repartidor_uid': repartidorUid,
          'repartidor_nombre': repartidorNombre,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}