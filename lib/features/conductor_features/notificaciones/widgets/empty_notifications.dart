import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class EmptyNotifications extends StatelessWidget {
  const EmptyNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: Palette.ink.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no tienes notificaciones',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Palette.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando haya cambios en pedidos o avisos del sistema, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
