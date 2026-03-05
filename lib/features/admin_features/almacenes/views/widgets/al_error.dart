import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AlmacenesErrorBox extends StatelessWidget {
  final String message;

  const AlmacenesErrorBox({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.statsDanger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Palette.statsDanger.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
