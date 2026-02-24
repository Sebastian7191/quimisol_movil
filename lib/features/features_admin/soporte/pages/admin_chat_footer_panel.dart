import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/soporte/pages/admin_chat_page.dart';

class AdminChatFooterPanel extends StatefulWidget {
  const AdminChatFooterPanel({super.key});

  @override
  State<AdminChatFooterPanel> createState() => _AdminChatFooterPanelState();
}

class _AdminChatFooterPanelState extends State<AdminChatFooterPanel>
    with TickerProviderStateMixin {
  bool _open = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _toggle() => setState(() => _open = !_open);

  void _openChatDetail(_AdminChatPreview chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminSupportChatPage(
          chatId: chat.chatId,
          clientName: chat.userName,
        ),
      ),
    );
  }

  void _openFullSupportPage(List<_AdminChatPreview> chats) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, animation, __) {
          return _AdminSoporteFullPageInline(
            chats: chats,
            onOpenChat: _openChatDetail,
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInOutCubic,
          );

          final scale = Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          );

          final slide = Tween<Offset>(
            begin: const Offset(-0.015, 0.045),
            end: Offset.zero,
          ).animate(curved);

          final radius = Tween<double>(begin: 24, end: 0).animate(curved);
          final shadowOpacity =
              Tween<double>(begin: 0.16, end: 0.0).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                alignment: Alignment.bottomLeft,
                scale: scale,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return Container(
                      margin: EdgeInsets.lerp(
                        const EdgeInsets.fromLTRB(10, 72, 10, 18),
                        EdgeInsets.zero,
                        curved.value,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius.value),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(shadowOpacity.value),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Stream<List<_AdminChatPreview>> _supportChatsStream() {
    return _db
        .collection('support_chats')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((d) => _AdminChatPreview.fromFirestore(d))
          .where((c) {
            if (c.status == 'draft') return false;
            if (c.status == 'cancelled_by_client') return false;
            return true;
          })
          .toList();

      items.sort((a, b) {
        final pa = _statusPriority(a.status);
        final pb = _statusPriority(b.status);
        if (pa != pb) return pa.compareTo(pb);

        final aMs = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

      return items;
    });
  }

  static int _statusPriority(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'in_progress':
        return 1;
      case 'completed':
        return 2;
      default:
        return 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final isMobile = w < 900;

    final double panelWidth =
        isMobile ? (w - 20).clamp(260.0, 340.0).toDouble() : 360.0;
    final double panelMaxHeight = isMobile ? (h * 0.48) : 380.0;

    return StreamBuilder<List<_AdminChatPreview>>(
      stream: _supportChatsStream(),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? const <_AdminChatPreview>[];
        final totalUnread = chats.fold<int>(0, (sum, e) => sum + e.unread);

        return SizedBox(
          width: panelWidth,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeInOutCubicEmphasized,
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeInOutCubicEmphasized,
                  alignment: Alignment.bottomLeft,
                  child: _open
                      ? TweenAnimationBuilder<double>(
                          key: const ValueKey('chat_panel_tween'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            final translateY = (1 - t) * 18;
                            final scale = 0.94 + (0.06 * t);

                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, translateY),
                                child: Transform.scale(
                                  alignment: Alignment.bottomLeft,
                                  scale: scale,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: panelWidth,
                            constraints: BoxConstraints(maxHeight: panelMaxHeight),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Palette.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Palette.button.withOpacity(0.20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Header(
                                  onClose: _toggle,
                                  totalUnread: totalUnread,
                                  onExpand: () => _openFullSupportPage(chats),
                                ),
                                const Divider(height: 1),
                                Flexible(
                                  child: Builder(
                                    builder: (_) {
                                      if (snapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          chats.isEmpty) {
                                        return const _ChatsLoadingState();
                                      }

                                      if (snapshot.hasError) {
                                        return const _ChatsErrorState(
                                          message: 'No se pudo cargar soporte',
                                        );
                                      }

                                      if (chats.isEmpty) {
                                        return const _ChatsEmptyState();
                                      }

                                      return ListView.separated(
                                        padding: const EdgeInsets.all(8),
                                        shrinkWrap: true,
                                        itemCount: chats.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 4),
                                        itemBuilder: (_, i) {
                                          final chat = chats[i];
                                          return _ChatListTile(
                                            chat: chat,
                                            compact: true,
                                            onTap: () => _openChatDetail(chat),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubicEmphasized,
                      padding: EdgeInsets.symmetric(
                        horizontal: _open ? 14 : 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Palette.button.withOpacity(0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(_open ? 0.22 : 0.16),
                            blurRadius: _open ? 20 : 16,
                            offset: Offset(0, _open ? 10 : 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedScale(
                                scale: _open ? 1.06 : 1.0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                child: const Icon(
                                  Icons.support_agent_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              if (totalUnread > 0)
                                Positioned(
                                  right: -5,
                                  top: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.button,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      '$totalUnread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _open ? 'Soporte (abierto)' : 'Soporte',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _open ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final int totalUnread;
  final VoidCallback? onExpand;

  const _Header({
    required this.onClose,
    required this.totalUnread,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Palette.button.withOpacity(0.15),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: Palette.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Chats de soporte',
              style: TextStyle(
                color: Palette.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          if (totalUnread > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Palette.button.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$totalUnread sin leer',
                style: const TextStyle(
                  color: Palette.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            onPressed: onExpand,
            splashRadius: 18,
            tooltip: 'Abrir grande',
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Palette.button.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                size: 17,
                color: Palette.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            splashRadius: 18,
            tooltip: 'Cerrar',
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 17,
                color: Palette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final _AdminChatPreview chat;
  final VoidCallback onTap;
  final bool compact;

  const _ChatListTile({
    required this.chat,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatarR = compact ? 20.0 : 24.0;
    final nameSize = compact ? 13.2 : 15.0;
    final msgSize = compact ? 12.1 : 13.4;
    final timeSize = compact ? 10.5 : 11.8;
    final verticalPad = compact ? 9.0 : 12.0;
    final horizontalPad = compact ? 10.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: verticalPad,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Palette.button.withOpacity(0.10),
            ),
            color: Palette.white,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: avatarR,
                    backgroundColor: Palette.fieldBg,
                    child: Text(
                      _initials(chat.userName),
                      style: TextStyle(
                        color: Palette.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12 : 13.5,
                      ),
                    ),
                  ),
                  if (chat.online)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: compact ? 11 : 13,
                        height: compact ? 11 : 13,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: nameSize,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chat.lastMessage,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Palette.ink.withOpacity(0.65),
                        fontSize: msgSize,
                        height: 1.15,
                        fontWeight:
                            chat.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      _StatusChip(status: chat.status),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat.time,
                    style: TextStyle(
                      color: Palette.ink.withOpacity(0.55),
                      fontSize: timeSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  if (chat.unread > 0)
                    Container(
                      constraints: BoxConstraints(minWidth: compact ? 20 : 24),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 7,
                        vertical: compact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.button,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${chat.unread}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: compact ? 16 : 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Pendiente', Colors.orange),
      'in_progress' => ('En atención', Colors.blue),
      'completed' => ('Completado', Colors.green),
      _ => ('Otro', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatsLoadingState extends StatelessWidget {
  const _ChatsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Palette.primary),
            const SizedBox(height: 10),
            Text(
              'Cargando chats...',
              style: TextStyle(
                color: Palette.primary.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsEmptyState extends StatelessWidget {
  const _ChatsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 34,
              color: Palette.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay tickets de soporte',
              style: TextStyle(
                color: Palette.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando un cliente abra un ticket aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.ink.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsErrorState extends StatelessWidget {
  final String message;

  const _ChatsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 30),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminChatPreview {
  final String chatId;
  final String userName;
  final String lastMessage;
  final String time;
  final int unread;
  final bool online;
  final String status;
  final DateTime? lastMessageAt;

  const _AdminChatPreview({
    required this.chatId,
    required this.userName,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.online,
    required this.status,
    required this.lastMessageAt,
  });

  factory _AdminChatPreview.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    final clientName = (d['clientName'] ?? 'Cliente').toString();
    final lastMessageRaw = d['lastMessage'];
    final lastMessageType = (d['lastMessageType'] ?? '').toString();
    final unreadCountSupport = (d['unreadCountSupport'] ?? 0) is int
        ? (d['unreadCountSupport'] ?? 0) as int
        : int.tryParse('${d['unreadCountSupport']}') ?? 0;

    final status = (d['status'] ?? '').toString();

    DateTime? lastAt;
    final ts = d['lastMessageAt'] ?? d['updatedAt'];
    if (ts is Timestamp) {
      lastAt = ts.toDate();
    }

    final lastMessage = _resolveLastMessage(
      raw: lastMessageRaw,
      type: lastMessageType,
      status: status,
    );

    return _AdminChatPreview(
      chatId: (d['chatId'] ?? doc.id).toString(),
      userName: clientName,
      lastMessage: lastMessage,
      time: _formatChatTime(lastAt),
      unread: unreadCountSupport,
      online: false,
      status: status,
      lastMessageAt: lastAt,
    );
  }

  static String _resolveLastMessage({
    required dynamic raw,
    required String type,
    required String status,
  }) {
    final txt = (raw ?? '').toString().trim();

    if (txt.isNotEmpty) return txt;
    if (type == 'image') return '📷 Imagen';

    if (status == 'pending') return 'Ticket pendiente';
    if (status == 'in_progress') return 'Ticket en atención';
    if (status == 'completed') return 'Ticket completado';

    return 'Sin mensajes';
  }

  static String _formatChatTime(DateTime? dt) {
    if (dt == null) return '--:--';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);

    final diffDays = today.difference(d).inDays;

    if (diffDays == 0) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    if (diffDays == 1) return 'Ayer';

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _AdminSoporteFullPageInline extends StatelessWidget {
  final List<_AdminChatPreview> chats;
  final ValueChanged<_AdminChatPreview> onOpenChat;

  const _AdminSoporteFullPageInline({
    required this.chats,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final totalUnread = chats.fold<int>(0, (sum, e) => sum + e.unread);

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Palette.button.withOpacity(0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Palette.button.withOpacity(0.14),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Palette.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soporte',
                          style: TextStyle(
                            color: Palette.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chats de soporte (vista ampliada)',
                          style: TextStyle(
                            color: Palette.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalUnread > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.button.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$totalUnread sin leer',
                        style: const TextStyle(
                          color: Palette.primary,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 20,
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Palette.fieldBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Palette.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.button.withOpacity(0.14)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Palette.ink.withOpacity(0.65),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buscar chats (UI)',
                      style: TextStyle(
                        color: Palette.ink.withOpacity(0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Palette.button.withOpacity(0.14),
                  ),
                ),
                child: chats.isEmpty
                    ? const _ChatsEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final chat = chats[i];
                          return _ChatListTile(
                            chat: chat,
                            compact: false,
                            onTap: () => onOpenChat(chat),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}