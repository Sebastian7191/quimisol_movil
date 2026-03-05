import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/admin_features/banners/controllers/banners_dialog_controller.dart';


class ProductListSelector extends StatelessWidget {
  const ProductListSelector({
    super.key,
    required this.products,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.height = 280,
  });

  final List<BannerProductOption> products;
  final BannerProductOption? selected;
  final ValueChanged<BannerProductOption?> onSelected;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: LayoutBuilder(
              builder: (context, c) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: c.maxWidth,
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: Palette.ink.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Producto (opcional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Palette.ink,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: (!enabled || selected == null) ? null : () => onSelected(null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Quitar'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: Palette.button.withValues(alpha: 0.16)),
          Expanded(
            child: !enabled
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : products.isEmpty
                    ? Center(
                        child: Text(
                          'No hay productos',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Palette.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Palette.button.withValues(alpha: 0.12),
                        ),
                        itemBuilder: (_, i) {
                          final p = products[i];
                          final isSelected = selected?.id == p.id;

                          return InkWell(
                            onTap: () => onSelected(p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.nombre.isEmpty ? '(sin nombre)' : p.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Palette.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _Thumb(url: p.imagenUrl),
                                  const SizedBox(width: 10),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Palette.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Palette.primary.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: const Text(
                                        'Seleccionado',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: Palette.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Palette.ink.withValues(alpha: 0.25),
      ),
    );

    if (url.trim().isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
