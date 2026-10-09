import 'package:cloud_firestore/cloud_firestore.dart';

class EntregaItem {
  final String id;

  final String? pedidoCodigo;
  final String? clienteNombre;
  final String? direccion;

  final double? total;
  final String estado;

  final double? rating; // 1..5
  final String? ratingComment;

  final DateTime deliveredAt;

  EntregaItem({
    required this.id,
    required this.estado,
    required this.deliveredAt,
    this.pedidoCodigo,
    this.clienteNombre,
    this.direccion,
    this.total,
    this.rating,
    this.ratingComment,
  });

  factory EntregaItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    DateTime deliveredAt = DateTime.now();
    final ts = d['delivered_at'];
    if (ts is Timestamp) deliveredAt = ts.toDate();

    double? total;
    final t = d['total'];
    if (t is num) total = t.toDouble();

    double? rating;
    final r = d['rating'];
    if (r is num) rating = r.toDouble();

    return EntregaItem(
      id: doc.id,
      pedidoCodigo: d['codigo']?.toString(),
      clienteNombre: d['cliente_nombre']?.toString(),
      direccion: d['direccion']?.toString(),
      total: total,
      estado: (d['estado'] ?? 'desconocido').toString(),
      rating: rating,
      ratingComment: d['rating_comment']?.toString(),
      deliveredAt: deliveredAt,
    );
  }
}
