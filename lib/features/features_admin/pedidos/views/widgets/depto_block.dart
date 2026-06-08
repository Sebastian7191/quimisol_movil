import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

/* ================= SECCIONES POR DEPTO ================= */

class DeptoBlock extends StatelessWidget {
  const DeptoBlock({
    super.key,
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.primary.withValues(alpha: 0.10)),
                ),
                child: const Icon(Icons.map_rounded, color: Palette.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Palette.fieldBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ink.withValues(alpha: 0.06)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
