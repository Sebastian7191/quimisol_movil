import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoRow {
  final String id;
  final String codigo;
  final String estado;
  final String direccion;
  final String departamento;
  final int conteoItems;
  final double total;
  final double costoEnvio;
  final DateTime? createdAt;

  // NUEVO
  final String tipoPago;
  final String estadoPago;

  // Labels precomputadas por el controller para facilitar la UI
  final String fechaLabel;
  final String totalLabel;

  PedidoRow({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.direccion,
    required this.departamento,
    required this.conteoItems,
    required this.total,
    required this.costoEnvio,
    required this.createdAt,
    required this.tipoPago,
    required this.estadoPago,
    this.fechaLabel = '',
    this.totalLabel = '',
  });

  double get totalFinal => total + costoEnvio;

  factory PedidoRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();

    return PedidoRow(
      id: d.id,
      codigo: (data['codigo'] ?? '').toString(),
      estado: (data['estado'] ?? 'pendiente').toString().toLowerCase(),
      direccion: (data['direccion'] ?? '').toString(),
      departamento: (data['departamento'] ?? 'Sin departamento').toString(),
      conteoItems: _resolveConteoItems(data),
      total: _asDouble(data['total']),
      costoEnvio: _asDouble(data['costo_envio']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,

      // NUEVO
      tipoPago: _normalizeTipoPago(
        data['tipo_pago'] ?? data['tipoPago'],
      ),
      estadoPago: _normalizeEstadoPago(
        data['estado_pago'] ?? data['estadoPago'],
      ),
    );
  }

  PedidoRow copyWith({
    String? fechaLabel,
    String? totalLabel,
  }) {
    return PedidoRow(
      id: id,
      codigo: codigo,
      estado: estado,
      direccion: direccion,
      departamento: departamento,
      conteoItems: conteoItems,
      total: total,
      costoEnvio: costoEnvio,
      createdAt: createdAt,
      tipoPago: tipoPago,
      estadoPago: estadoPago,
      fechaLabel: fechaLabel ?? this.fechaLabel,
      totalLabel: totalLabel ?? this.totalLabel,
    );
  }
}

int _resolveConteoItems(Map<String, dynamic> data) {
  final rawConteo = data['conteoItems'];
  if (rawConteo is num) return rawConteo.toInt();

  final rawItems = data['items'];
  if (rawItems is List) return rawItems.length;

  return 0;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
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