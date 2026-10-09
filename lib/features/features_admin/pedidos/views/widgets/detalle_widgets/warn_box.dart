import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class WarnBox extends StatelessWidget {
  const WarnBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.button.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ink.withValues(alpha: 0.75)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ink.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                fontSize: 12.2,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}