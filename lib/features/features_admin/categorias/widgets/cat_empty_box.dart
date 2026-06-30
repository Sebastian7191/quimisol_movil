import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class CategoriasEmptyBox extends StatelessWidget {
  final String title;
  final String subtitle;

  const CategoriasEmptyBox({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_rounded,
              size: 44,
              color: Palette.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
