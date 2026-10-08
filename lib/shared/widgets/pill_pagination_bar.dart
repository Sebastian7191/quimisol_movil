import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

/// Barra de paginación estilo "píldora" (pantallas de cliente y repartidor):
/// "Mostrando 1–6 de 20 [itemLabel]", botones
/// Anterior / Siguiente y puntos (o "2 / 9" si hay muchas páginas).
class PillPaginationBar extends StatelessWidget {
  const PillPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onChanged,
    this.itemLabel = 'productos',
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onChanged;

  /// Qué se está paginando, en plural ("productos", "pedidos").
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final from = currentPage * pageSize + 1;
    final to = math.min((currentPage + 1) * pageSize, totalItems);
    final hasPrev = currentPage > 0;
    final hasNext = currentPage < totalPages - 1;

    return Column(
      children: [
        Text(
          'Mostrando $from–$to de $totalItems $itemLabel',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Palette.ink.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PillNavButton(
              label: 'Anterior',
              icon: Icons.chevron_left_rounded,
              iconLeading: true,
              enabled: hasPrev,
              onTap: () => onChanged(currentPage - 1),
            ),
            // Dots: tap para ir directo a esa página
            if (totalPages <= 8)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalPages, (i) {
                  final active = i == currentPage;
                  return GestureDetector(
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 8,
                      width: active ? 22 : 8,
                      decoration: BoxDecoration(
                        color: active
                            ? Palette.button
                            : Palette.ink.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                }),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Palette.ink.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Palette.ink,
                  ),
                ),
              ),
            _PillNavButton(
              label: 'Siguiente',
              icon: Icons.chevron_right_rounded,
              iconLeading: false,
              enabled: hasNext,
              onTap: () => onChanged(currentPage + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _PillNavButton extends StatelessWidget {
  const _PillNavButton({
    required this.label,
    required this.icon,
    required this.iconLeading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool iconLeading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 18,
      color: enabled ? Palette.white : Palette.ink.withValues(alpha: 0.35),
    );
    final labelWidget = Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: enabled ? Palette.white : Palette.ink.withValues(alpha: 0.35),
      ),
    );

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? Palette.button
                : Palette.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Palette.button.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconLeading
                ? [iconWidget, const SizedBox(width: 4), labelWidget]
                : [labelWidget, const SizedBox(width: 4), iconWidget],
          ),
        ),
      ),
    );
  }
}
