import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/productos/controllers/producto_dialog_controller.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_ui.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/promo_banner_preview.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/producto_card_preview.dart';

class ProductoDialogPreviewPanel extends StatelessWidget {
  const ProductoDialogPreviewPanel({super.key, required this.controller});

  final ProductoDialogController controller;

  @override
  Widget build(BuildContext context) {
    return ProductoDialogUI.card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool hasBoundedHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

          Widget previewBody = ValueListenableBuilder<int>(
            valueListenable: controller.previewTick,
            builder: (_, __, ___) {
              final name = controller.nombreCtrl.text.trim().isEmpty
                  ? 'Producto'
                  : controller.nombreCtrl.text.trim();

              final base = controller.precioBaseNow();
              final finalPrice = controller.precioFinalPreview();
              final hasDiscount =
                  controller.descuentoEnabled && finalPrice < base;

              String? discountText;
              if (hasDiscount) {
                final val = controller.parseDouble(
                  controller.descuentoCtrl.text,
                );
                if (controller.descuentoTipo == 'PORCENTAJE') {
                  final pct = val.clamp(0, 100);
                  discountText =
                      'DESCUENTO -${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 2)}%';
                } else {
                  discountText = 'DESCUENTO -Bs ${val.toStringAsFixed(2)}';
                }
              }

              const double phoneWidth = 292;

              final phone = SizedBox(
                width: phoneWidth,
                child: PhonePreviewFrame(
                  title: 'Vista previa móvil',
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final double cardW = (c.maxWidth * 0.92).clamp(
                        195.0,
                        240.0,
                      );

                      return ColoredBox(
                        color: Palette.white,
                        child: ScrollConfiguration(
                          behavior: const _NoScrollbarScrollBehavior(),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(top: 10, bottom: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (controller.promoBannerEnabled)
                                  PromoBannerPreview(
                                    productTitle: name,
                                    discountSubtitle: _buildDiscountSubtitle(
                                      controller,
                                      hasDiscount: hasDiscount,
                                    ),
                                    imageBytes: controller.pickedBytes,
                                    imageUrl: controller.existingImageUrl,

                                    // ⚠️ Si tu widget ya NO usa botón, borra esta línea
                                    // buttonText: 'Ver más',
                                  ),
                                if (controller.promoBannerEnabled)
                                  const SizedBox(height: 14),

                                Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: cardW,
                                    ),
                                    child: ProductoCardPreview(
                                      name: name,
                                      stock: controller.parseStock(
                                        controller.stockCtrl.text,
                                      ),
                                      priceFinal: hasDiscount
                                          ? finalPrice
                                          : base,
                                      priceBase: hasDiscount ? base : null,
                                      discountBadgeText: discountText,
                                      imageUrl: controller.existingImageUrl,
                                      pickedBytes: controller.pickedBytes,
                                      rating: 0.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );

              // Encajar dentro del panel
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: phone,
                ),
              );
            },
          );

          // ✅ SI está dentro de un scroll (móvil) -> NO uses Expanded.
          //    Dale un alto fijo para que renderice.
          if (!hasBoundedHeight) {
            previewBody = SizedBox(height: 560, child: previewBody);
          } else {
            previewBody = Expanded(child: previewBody);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Palette.button.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Palette.button.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.phone_iphone_rounded,
                      color: Palette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Vista previa',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Palette.ink,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              previewBody,
            ],
          );
        },
      ),
    );
  }

  String _buildDiscountSubtitle(
    ProductoDialogController controller, {
    required bool hasDiscount,
  }) {
    if (!controller.descuentoEnabled || !hasDiscount)
      return '¡No te lo pierdas!';

    final val = controller.parseDouble(controller.descuentoCtrl.text);
    if (val <= 0) return '¡No te lo pierdas!';

    if (controller.descuentoTipo == 'PORCENTAJE') {
      final pct = val.clamp(0, 100);
      final pctStr = pct.toStringAsFixed(pct % 1 == 0 ? 0 : 2);
      return 'Descuento ($pctStr%) ¡No te lo pierdas!';
    } else {
      final bsStr = val.toStringAsFixed(2);
      return 'Descuento (Bs $bsStr) ¡No te lo pierdas!';
    }
  }
}

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
