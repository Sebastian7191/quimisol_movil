import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String? type; // pedido, sistema, pago, etc.
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.type,
    this.data,
  });

  factory NotificationItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    final ts = d['created_at'];
    DateTime createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return NotificationItem(
      id: doc.id,
      title: (d['title'] ?? 'Notificación') as String,
      body: (d['body'] ?? '') as String,
      type: d['type'] as String?,
      read: (d['read'] ?? false) as bool,
      createdAt: createdAt,
      data: (d['data'] is Map) ? Map<String, dynamic>.from(d['data']) : null,
    );
  }
}
