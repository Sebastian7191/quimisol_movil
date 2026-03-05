import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class EmptyBox extends StatelessWidget {
  const EmptyBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: ink.withValues(alpha: 0.55)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ink.withValues(alpha: 0.70),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}