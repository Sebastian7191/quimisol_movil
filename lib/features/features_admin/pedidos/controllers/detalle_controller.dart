import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/detalle_data.dart';

/// Otro pedido del repartidor que choca con la hora del pedido actual.
class PedidoOcupado {
  final String codigo;
  final DateTime fechaEnvio;

  const PedidoOcupado({required this.codigo, required this.fechaEnvio});

  /// "14:30" o "05/10 14:30" si es otro día que [referencia].
  String horaTexto(DateTime referencia) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hora = '${two(fechaEnvio.hour)}:${two(fechaEnvio.minute)}';
    final mismoDia =
        fechaEnvio.year == referencia.year &&
        fechaEnvio.month == referencia.month &&
        fechaEnvio.day == referencia.day;
    return mismoDia
        ? hora
        : '${two(fechaEnvio.day)}/${two(fechaEnvio.month)} $hora';
  }
}

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

  /// Margen para considerar ocupado a un repartidor: otro pedido suyo con
  /// fecha de envío a menos de esto de la del pedido actual.
  static const Duration ventanaOcupado = Duration(hours: 1);

  /// Repartidores que ya tienen otro pedido activo cerca de [fecha].
  /// Devuelve uid del repartidor → pedidos que chocan.
  Future<Map<String, List<PedidoOcupado>>> fetchOcupados({
    required DateTime fecha,
    required String excluirPedidoId,
  }) async {
    // Rango sobre un solo campo: no requiere índice compuesto.
    final snap = await _fire
        .collection('pedidos')
        .where(
          'fecha_envio',
          isGreaterThan: Timestamp.fromDate(fecha.subtract(ventanaOcupado)),
        )
        .where(
          'fecha_envio',
          isLessThan: Timestamp.fromDate(fecha.add(ventanaOcupado)),
        )
        .get();

    const finalizados = {
      'entregado',
      'completado',
      'completada',
      'cancelado',
      'cancelada',
    };

    final out = <String, List<PedidoOcupado>>{};
    for (final d in snap.docs) {
      if (d.id == excluirPedidoId) continue;
      final data = d.data();

      final estado = (data['estado'] ?? '').toString().trim().toLowerCase();
      if (finalizados.contains(estado)) continue;

      final rep = (data['repartidorUid'] ?? data['repartidor_uid'] ?? '')
          .toString()
          .trim();
      final ts = data['fecha_envio'];
      if (rep.isEmpty || ts is! Timestamp) continue;

      out
          .putIfAbsent(rep, () => [])
          .add(
            PedidoOcupado(
              codigo: (data['codigo'] ?? '').toString().trim(),
              fechaEnvio: ts.toDate(),
            ),
          );
    }

    for (final list in out.values) {
      list.sort((a, b) => a.fechaEnvio.compareTo(b.fechaEnvio));
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
    final estadoFinal = estadoPagoFinal == 'rechazado'
        ? 'pendiente'
        : nuevoEstado;
    final motivoFinal = estadoPagoFinal == 'rechazado'
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

    // Al pasar a cancelado empiezan las 48 h del cliente para hablar con
    // soporte (solo la primera vez, no en cada edición).
    final estadoAntes = (data['estado'] ?? '').toString().toLowerCase();
    final pasaACancelado =
        estadoFinal.toLowerCase().contains('cancel') &&
        !estadoAntes.contains('cancel');
    if (pasaACancelado) {
      payload['canceladoAt'] = FieldValue.serverTimestamp();
    }

    final batch = _fire.batch();
    batch.set(pedidoRef, payload, SetOptions(merge: true));

    if (uid.isNotEmpty) {
      final userPedidoRef = _fire
          .collection('usuarios')
          .doc(uid)
          .collection('pedidos')
          .doc(pedidoId);

      batch.set(userPedidoRef, {
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
        if (pasaACancelado) 'canceladoAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
