import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/admin_features/banners/controllers/banners_dialog_controller.dart';


class ProductAutocompleteField extends StatelessWidget {
  const ProductAutocompleteField({
    super.key,
    required this.products,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.requiredSelection = false,
  });

  final List<BannerProductOption> products;
  final BannerProductOption? selected;
  final ValueChanged<BannerProductOption> onSelected;
  final bool enabled;
  final bool requiredSelection;

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.sizeOf(context).width;
    final maxPanelW = (vw - 32).clamp(260.0, 520.0);

    return Autocomplete<BannerProductOption>(
      initialValue: TextEditingValue(text: selected?.nombre ?? ''),
      displayStringForOption: (o) => o.nombre,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return products.take(20);
        return products.where((p) {
          final n = p.nombre.toLowerCase();
          return n.contains(q) || p.id.toLowerCase().contains(q);
        }).take(30);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'Producto (opcional)',
            hintText: 'Escribe para buscar producto...',
            filled: true,
            fillColor: Palette.fieldBg,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Palette.ink.withValues(alpha: 0.65),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          validator: (v) {
            if (!requiredSelection) return null;
            if ((selected?.id ?? '').trim().isEmpty) return 'Selecciona un producto';
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelectedOpt, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: Palette.white,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPanelW, maxHeight: 320),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Palette.button.withValues(alpha: 0.15),
                ),
                itemBuilder: (_, i) {
                  final p = options.elementAt(i);
                  final img = p.imagenUrl.trim();

                  return InkWell(
                    onTap: () => onSelectedOpt(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre.isEmpty ? '(sin nombre)' : p.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Palette.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.ink.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Thumb(url: img),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: onSelected,
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
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Palette.ink.withValues(alpha: 0.28),
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
