import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  late final TabController _tabController;

  final Set<String> _loadingReadIds = {};

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _notiRef =>
      _fire.collection('usuarios').doc(_uid).collection('notificaciones');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamTodas() {
    return _notiRef.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamNoLeidas() {
    return _notiRef
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamLeidas() {
    return _notiRef
        .where('read', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markAsRead(String notiId) async {
    if (_uid.isEmpty) return;
    if (_loadingReadIds.contains(notiId)) return;

    setState(() => _loadingReadIds.add(notiId));

    try {
      await _notiRef.doc(notiId).set({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo marcar como leído: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingReadIds.remove(notiId));
      }
    }
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Sin fecha';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  IconData _iconForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'nuevo_pedido_pendiente':
        return Icons.receipt_long_rounded;
      case 'pedido_entregado':
        return Icons.local_shipping_rounded;
      case 'support_chat':
        return Icons.support_agent_rounded;
      case 'general':
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'nuevo_pedido_pendiente':
        return Palette.primary;
      case 'pedido_entregado':
        return Palette.statsSuccess;
      case 'support_chat':
        return Palette.button;
      case 'general':
        return Palette.primary;
      default:
        return Palette.primary;
    }
  }

  String _labelForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'nuevo_pedido_pendiente':
        return 'Pedido';
      case 'pedido_entregado':
        return 'Entrega';
      case 'support_chat':
        return 'Soporte';
      case 'general':
        return 'General';
      default:
        return 'Notificación';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: _uid.isEmpty
          ? SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No hay usuario autenticado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Palette.button, Palette.gradientEnd],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 42,
                                  width: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.20),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Notificaciones',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 54),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Palette.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Palette.ink.withOpacity(0.06),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: Palette.button.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              labelColor: Palette.primary,
                              unselectedLabelColor: ink.withOpacity(0.60),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(text: 'Bandeja'),
                                Tab(text: 'No leídos'),
                                Tab(text: 'Leídos'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _NotificacionesList(
                        stream: _streamTodas(),
                        emptyIcon: Icons.inbox_outlined,
                        emptyTitle: 'Tu bandeja está vacía',
                        emptySubtitle:
                            'Aquí aparecerán todas tus notificaciones.',
                        loadingReadIds: _loadingReadIds,
                        onMarkRead: _markAsRead,
                        labelForType: _labelForType,
                        iconForType: _iconForType,
                        colorForType: _colorForType,
                        fmtDate: _fmtDate,
                        toStr: _s,
                        asDate: _asDate,
                      ),
                      _NotificacionesList(
                        stream: _streamNoLeidas(),
                        emptyIcon: Icons.mark_email_unread_outlined,
                        emptyTitle: 'No tienes notificaciones sin leer',
                        emptySubtitle:
                            'Cuando llegue una nueva, aparecerá aquí.',
                        loadingReadIds: _loadingReadIds,
                        onMarkRead: _markAsRead,
                        labelForType: _labelForType,
                        iconForType: _iconForType,
                        colorForType: _colorForType,
                        fmtDate: _fmtDate,
                        toStr: _s,
                        asDate: _asDate,
                      ),
                      _NotificacionesList(
                        stream: _streamLeidas(),
                        emptyIcon: Icons.drafts_outlined,
                        emptyTitle: 'No tienes notificaciones leídas',
                        emptySubtitle:
                            'Las notificaciones marcadas como leídas aparecerán aquí.',
                        loadingReadIds: _loadingReadIds,
                        onMarkRead: _markAsRead,
                        labelForType: _labelForType,
                        iconForType: _iconForType,
                        colorForType: _colorForType,
                        fmtDate: _fmtDate,
                        toStr: _s,
                        asDate: _asDate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificacionesList extends StatelessWidget {
  const _NotificacionesList({
    required this.stream,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.loadingReadIds,
    required this.onMarkRead,
    required this.labelForType,
    required this.iconForType,
    required this.colorForType,
    required this.fmtDate,
    required this.toStr,
    required this.asDate,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Set<String> loadingReadIds;
  final Future<void> Function(String id) onMarkRead;
  final String Function(String type) labelForType;
  final IconData Function(String type) iconForType;
  final Color Function(String type) colorForType;
  final String Function(DateTime? d) fmtDate;
  final String Function(dynamic v) toStr;
  final DateTime? Function(dynamic v) asDate;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                'Error cargando notificaciones: ${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    emptyIcon,
                    size: 56,
                    color: ink.withOpacity(0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withOpacity(0.58),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();

            final title = toStr(data['title']).isEmpty
                ? 'Notificación'
                : toStr(data['title']);
            final body = toStr(data['body']).isEmpty
                ? 'Tienes una nueva notificación.'
                : toStr(data['body']);
            final type = toStr(data['type']).isEmpty
                ? 'general'
                : toStr(data['type']);
            final read = data['read'] == true;
            final createdAt = asDate(data['createdAt']);
            final color = colorForType(type);
            final isLoading = loadingReadIds.contains(d.id);

            return _NotificacionCard(
              title: title,
              body: body,
              typeLabel: labelForType(type),
              dateLabel: fmtDate(createdAt),
              read: read,
              icon: iconForType(type),
              accent: color,
              isLoading: isLoading,
              onMarkRead: read ? null : () => onMarkRead(d.id),
            );
          },
        );
      },
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  const _NotificacionCard({
    required this.title,
    required this.body,
    required this.typeLabel,
    required this.dateLabel,
    required this.read,
    required this.icon,
    required this.accent,
    required this.isLoading,
    required this.onMarkRead,
  });

  final String title;
  final String body;
  final String typeLabel;
  final String dateLabel;
  final bool read;
  final IconData icon;
  final Color accent;
  final bool isLoading;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: read ? Palette.white : accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: read ? ink.withOpacity(0.06) : accent.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.2,
                        ),
                      ),
                    ),
                    if (!read)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: ink.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    fontSize: 13.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MiniBadge(
                      text: typeLabel,
                      color: accent,
                    ),
                    _MiniBadgeMuted(text: dateLabel),
                  ],
                ),
                if (!read) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : onMarkRead,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.button,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.mark_email_read_rounded, size: 18),
                      label: Text(
                        isLoading ? 'Marcando...' : 'Marcar como leído',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11.8,
        ),
      ),
    );
  }
}

class _MiniBadgeMuted extends StatelessWidget {
  const _MiniBadgeMuted({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withOpacity(0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ink.withOpacity(0.58),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}