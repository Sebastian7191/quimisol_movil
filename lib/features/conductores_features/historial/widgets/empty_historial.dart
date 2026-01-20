import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class EmptyHistorial extends StatelessWidget {
  const EmptyHistorial({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 60,
              color: Palette.ink.withOpacity(0.35),
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no tienes entregas',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Palette.ink.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando completes pedidos, aparecerán aquí con su calificación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.ink.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
