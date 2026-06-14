import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int currentPage;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / pageSize).ceil().clamp(1, 99999);
    final displayPage = currentPage + 1;
    final start = currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        border: Border(
          top: BorderSide(color: Palette.primary.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Página anterior',
            onTap: onPrev,
          ),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Palette.ink,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: 'Página ',
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
                TextSpan(
                  text: '$displayPage',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.primary,
                  ),
                ),
                TextSpan(
                  text: ' de $totalPages',
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
                TextSpan(
                  text: '  ($start–$end de $totalItems)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Palette.ink.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Página siguiente',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled
                  ? Palette.primary.withValues(alpha: 0.10)
                  : Palette.ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled
                    ? Palette.primary.withValues(alpha: 0.25)
                    : Palette.ink.withValues(alpha: 0.10),
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: enabled ? Palette.primary : Palette.ink.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
