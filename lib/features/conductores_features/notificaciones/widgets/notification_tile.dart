import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../data/models/notification_item.dart';

class NotificationTile extends StatelessWidget {
  final NotificationItem n;
  final String timeText;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const NotificationTile({
    super.key,
    required this.n,
    required this.timeText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !n.read;

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      onDismissed: (_) async => await onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? Palette.primary.withOpacity(0.30)
                  : Colors.black.withOpacity(0.06),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUnread
                      ? Palette.button.withOpacity(0.18)
                      : Colors.black.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: isUnread ? Palette.primary : Palette.ink.withOpacity(0.55),
                ),
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
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 14,
                              color: Palette.ink.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Palette.ink.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Palette.ink.withOpacity(0.7),
                      ),
                    ),
                    if (n.type != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Palette.fieldBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Text(
                          n.type!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Palette.primary.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
