import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// Devuelve la porción (página) de [items] correspondiente a [page]
/// (base 0) con tamaño [pageSize]. Si [page] queda fuera de rango por
/// un cambio de filtro, se recorta sin lanzar excepción.
List<T> paginate<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty || pageSize <= 0) return const [];
  final start = (page * pageSize).clamp(0, items.length);
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

/// Número total de páginas para [totalItems] con [pageSize] por página.
int pageCountFor(int totalItems, int pageSize) {
  if (totalItems <= 0 || pageSize <= 0) return 1;
  return ((totalItems - 1) ~/ pageSize) + 1;
}

/// Barra de paginación reutilizable: "Anterior · 1 2 … N · Siguiente"
/// con un texto "Mostrando X–Y de Z". Pensada para listas/grids del
/// panel de administración para evitar el scroll infinito.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.itemLabel = 'elementos',
  });

  /// Página actual (base 0).
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  /// Etiqueta del recurso para el texto de rango (ej. "usuarios").
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final totalPages = pageCountFor(totalItems, pageSize);
    if (totalItems == 0) return const SizedBox.shrink();

    final page = currentPage.clamp(0, totalPages - 1);
    final from = page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, totalItems);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mostrando $from–$to de $totalItems $itemLabel',
            style: TextStyle(
              fontSize: 12,
              color: Palette.ink.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                enabled: page > 0,
                onTap: () => onPageChanged(page - 1),
              ),
              const SizedBox(width: 4),
              ..._buildPageButtons(page, totalPages),
              const SizedBox(width: 4),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                enabled: page < totalPages - 1,
                onTap: () => onPageChanged(page + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye los botones de número de página con una ventana centrada
  /// alrededor de la página actual y elipsis cuando hay muchas páginas.
  List<Widget> _buildPageButtons(int page, int totalPages) {
    final pages = _visiblePages(page, totalPages);
    final widgets = <Widget>[];
    int? prev;
    for (final p in pages) {
      if (prev != null && p - prev > 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('…', style: TextStyle(color: Colors.black45)),
        ));
      }
      widgets.add(_PageChip(
        number: p + 1,
        selected: p == page,
        onTap: () => onPageChanged(p),
      ));
      prev = p;
    }
    return widgets;
  }

  /// Índices de página (base 0) a mostrar: primera, última y una ventana
  /// alrededor de la actual.
  List<int> _visiblePages(int page, int totalPages) {
    if (totalPages <= 7) {
      return List<int>.generate(totalPages, (i) => i);
    }
    final set = <int>{0, totalPages - 1, page};
    for (var d = 1; d <= 1; d++) {
      if (page - d >= 0) set.add(page - d);
      if (page + d < totalPages) set.add(page + d);
    }
    final list = set.toList()..sort();
    return list;
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? Palette.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: selected ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : Palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? Palette.primary.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Palette.primary : Colors.black26,
          ),
        ),
      ),
    );
  }
}
