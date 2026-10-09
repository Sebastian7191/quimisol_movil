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
    String norm(dynamic v) =>
        (v ?? '').toString().toLowerCase().replaceAll(RegExp(r'\s+'), '');

    var dep = norm(departamento);

    // Si el pedido no trae departamento, se toma el de su almacén.
    if (dep.isEmpty && almacenId.trim().isNotEmpty) {
      final alm =
          await _fire.collection('almacenes').doc(almacenId.trim()).get();
      dep = norm(alm.data()?['departamento']);
    }

    // Sin departamento no se puede saber quién corresponde: no se muestra a nadie.
    if (dep.isEmpty) return [];

    final snap = await _fire.collection('usuarios').get();

    // Paso 1: filtrar solo repartidores activos
    final candidatos = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
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
      candidatos.add(d);
    }

    // Paso 2: recopilar almacenIds únicos de los candidatos
    final almacenIds = <String>{};
    for (final d in candidatos) {
      final data = d.data();
      final almId =
          (data['almacenId'] ??
                  data['almacen_id'] ??
                  data['almacenUid'] ??
                  data['almacen_uid'] ??
                  '')
              .toString()
              .trim();
      if (almId.isNotEmpty) almacenIds.add(almId);
    }

    // Paso 3: consultar los almacenes y construir mapa almacenId -> departamento
    final almacenDepMap = <String, String>{};
    for (final id in almacenIds) {
      final doc = await _fire.collection('almacenes').doc(id).get();
      if (doc.exists) {
        almacenDepMap[id] = norm(doc.data()?['departamento']);
      }
    }

    // Paso 4: filtrar por el departamento del almacén del repartidor
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in candidatos) {
      final data = d.data();
      final almId =
          (data['almacenId'] ??
                  data['almacen_id'] ??
                  data['almacenUid'] ??
                  data['almacen_uid'] ??
                  '')
              .toString()
              .trim();

      // Departamento del repartidor: el de su almacén; si no tiene almacén
      // (o el almacén no tiene departamento), el guardado en su usuario.
      var depRep = almId.isEmpty ? '' : (almacenDepMap[almId] ?? '');
      if (depRep.isEmpty) depRep = norm(data['departamento']);

      // Solo los del mismo departamento que el pedido.
      if (depRep == dep) out.add(d);
    }

    return out;
  }

  /// Margen alrededor de la fecha de envío dentro del cual un repartidor
  /// con otro pedido se considera ocupado.
  static const ventanaOcupado = Duration(hours: 1);

  /// Repartidores con otro pedido activo cerca de [fechaEnvio]
  /// (uid -> fecha de envío de ese otro pedido).
  Future<Map<String, DateTime>> fetchRepartidoresOcupados({
    required DateTime fechaEnvio,
    required String excludePedidoId,
  }) async {
    // Rango sobre un solo campo: no requiere índice compuesto.
    final snap = await _fire
        .collection('pedidos')
        .where(
          'fecha_envio',
          isGreaterThan: Timestamp.fromDate(fechaEnvio.subtract(ventanaOcupado)),
        )
        .where(
          'fecha_envio',
          isLessThan: Timestamp.fromDate(fechaEnvio.add(ventanaOcupado)),
        )
        .get();

    final out = <String, DateTime>{};
    for (final d in snap.docs) {
      if (d.id == excludePedidoId) continue;
      final data = d.data();

      final estado = (data['estado'] ?? '').toString().trim().toLowerCase();
      if (estado.contains('cancel') || estado.contains('entreg')) continue;

      final uid = (data['repartidorUid'] ?? data['repartidor_uid'] ?? '')
          .toString()
          .trim();
      final fecha = data['fecha_envio'];
      if (uid.isEmpty || fecha is! Timestamp) continue;

      out[uid] = fecha.toDate();
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

    final estadoActual = (data['estado'] ?? '').toString().trim().toLowerCase();
    if (estadoActual.contains('entreg')) {
      throw Exception('El pedido ya fue entregado y no puede modificarse.');
    }

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