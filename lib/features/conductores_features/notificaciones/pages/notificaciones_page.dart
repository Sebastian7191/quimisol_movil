import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import '../data/models/notification_item.dart';
import '../data/services/notifications_service.dart';
import '../widgets/empty_notifications.dart';
import '../widgets/notification_tile.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  final _service = NotificationsService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _service.markAllAsRead(uid: uid);
    _snack('Notificaciones marcadas como leídas');
  }

  Future<void> _clearAll() async {
    final uid = _uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vaciar notificaciones'),
        content: const Text('¿Seguro que quieres eliminar todas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _service.clearAll(uid: uid);
    _snack('Notificaciones eliminadas');
  }

  Future<void> _openNotification(NotificationItem n) async {
    final uid = _uid;
    if (uid == null) return;

    if (!n.read) {
      await _service.markAsRead(uid: uid, notifId: n.id);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(n.body, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 18, color: Palette.ink.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  _formatTime(n.createdAt),
                  style: TextStyle(color: Palette.ink.withOpacity(0.7)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Notificaciones'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Marcar todo como leído',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: uid == null ? null : _markAllRead,
          ),
          IconButton(
            tooltip: 'Vaciar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: uid == null ? null : _clearAll,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('No hay sesión activa'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.stream(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                final items = docs.map(NotificationItem.fromDoc).toList();

                if (items.isEmpty) return const EmptyNotifications();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return NotificationTile(
                      n: n,
                      timeText: _formatTime(n.createdAt),
                      onTap: () => _openNotification(n),
                      onDelete: () => _service.deleteNotification(uid: uid, notifId: n.id),
                    );
                  },
                );
              },
            ),
    );
  }
}
