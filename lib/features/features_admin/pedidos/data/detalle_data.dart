import 'package:cloud_firestore/cloud_firestore.dart';

import 'pedido_item.dart';

class PedidoDetalleData {
  final String id;
  final String codigo;
  final String estado;

  final String direccion;
  final String departamento;
  final String ubicacionNombre;

  final String uidCliente;

  final String almacenId;

  final DateTime? fechaEnvio;
  final double costoEnvio;

  final String? repartidorUid;
  final String? repartidorNombre;

  final double totalProductos;
  final double totalFinal;

  final List<PedidoItemData> items;

  final DateTime? createdAt;

  final String tipoPago;
  final String estadoPago;
  final String comprobanteUrl;
  final String comprobanteNombre;
  final String motivoRechazoPago;

  PedidoDetalleData({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.direccion,
    required this.departamento,
    required this.ubicacionNombre,
    required this.uidCliente,
    required this.almacenId,
    required this.fechaEnvio,
    required this.costoEnvio,
    required this.repartidorUid,
    required this.repartidorNombre,
    required this.totalProductos,
    required this.totalFinal,
    required this.items,
    required this.createdAt,
    required this.tipoPago,
    required this.estadoPago,
    required this.comprobanteUrl,
    required this.comprobanteNombre,
    required this.motivoRechazoPago,
  });

  factory PedidoDetalleData.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final ubic = _asMap(data['ubicacion']);

    final itemsRaw = (data['items'] is List) ? data['items'] as List : [];
    final items = itemsRaw
        .whereType<Map>()
        .map((e) => PedidoItemData.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final totalProductos = items.fold<double>(0, (sumT, e) => sumT + e.subtotal);
    final costoEnvio = _asDouble(data['costo_envio']);

    final almacenId = (data['almacenId'] ??
            data['almacen_id'] ??
            data['almacenUid'] ??
            data['almacen_uid'] ??
            '')
        .toString()
        .trim();

    final dep = ((data['departamento'] ?? '').toString().trim().isNotEmpty
            ? (data['departamento'] ?? '').toString()
            : (ubic['departamento'] ?? '').toString())
        .toString()
        .trim();

    final direccion = (data['direccion'] ?? '').toString().trim();
    final ubicNombre = (ubic['nombre'] ?? '').toString().trim();

    final repUidRaw = (data['repartidorUid'] ?? data['repartidor_uid'] ?? '')
        .toString()
        .trim();
    final repNombreRaw =
        (data['repartidorNombre'] ?? data['repartidor_nombre'] ?? '')
            .toString()
            .trim();

    return PedidoDetalleData(
      id: doc.id,
      codigo: (data['codigo'] ?? '—').toString(),
      estado: (data['estado'] ?? 'pendiente').toString(),
      direccion: direccion,
      departamento: dep,
      ubicacionNombre: ubicNombre,
      uidCliente: (data['uid'] ?? '').toString().trim(),
      almacenId: almacenId,
      fechaEnvio: _tsToDate(data['fecha_envio']),
      costoEnvio: costoEnvio,
      repartidorUid: repUidRaw.isEmpty ? null : repUidRaw,
      repartidorNombre: repNombreRaw.isEmpty ? null : repNombreRaw,
      totalProductos: totalProductos,
      totalFinal: totalProductos + costoEnvio,
      items: items,
      createdAt: _tsToDate(data['createdAt']),
      tipoPago: _normalizeTipoPago(
        data['tipo_pago'] ?? data['tipoPago'],
      ),
      estadoPago: _normalizeEstadoPago(
        data['estado_pago'] ?? data['estadoPago'],
      ),
      comprobanteUrl: (data['comprobante_url'] ?? '').toString().trim(),
      comprobanteNombre: (data['comprobante_nombre'] ?? '').toString().trim(),
      motivoRechazoPago: (data['motivo_rechazo_pago'] ?? '')
          .toString()
          .trim(),
    );
  }
}

/* helpers */
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

DateTime? _tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

String _normalizeTipoPago(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  if (s.isEmpty) return 'efectivo';

  if (s.contains('qr')) return 'qr';
  if (s.contains('efect')) return 'efectivo';

  return s;
}

String _normalizeEstadoPago(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  if (s.isEmpty) return 'pendiente';

  if (s.contains('pend')) return 'pendiente';
  if (s.contains('pag')) return 'pagado';
  if (s.contains('rech')) return 'rechazado';
  if (s.contains('verif')) return 'verificando';

  return s;
}