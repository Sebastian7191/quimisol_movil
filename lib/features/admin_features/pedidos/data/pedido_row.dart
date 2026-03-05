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
      conteoItems: (data['conteoItems'] is num)
          ? (data['conteoItems'] as num).toInt()
          : 0,
      total: _asDouble(data['total']),
      costoEnvio: _asDouble(data['costo_envio']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  PedidoRow copyWith({String? fechaLabel, String? totalLabel}) {
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
      fechaLabel: fechaLabel ?? this.fechaLabel,
      totalLabel: totalLabel ?? this.totalLabel,
    );
  }
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}
