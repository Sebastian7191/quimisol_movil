import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/admin_features/productos/controllers/producto_dialog_controller.dart';
import 'package:quimisol_movil/features/admin_features/productos/views/widgets/dialogs/producto_dialog_ui.dart';


class ProductoDialogDiscountBlock extends StatelessWidget {
  const ProductoDialogDiscountBlock({super.key, required this.controller});

  final ProductoDialogController controller;

  @override
  Widget build(BuildContext context) {
    return ProductoDialogUI.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: controller.agregarDescuento,
            items: const [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('— Seleccionar —'),
              ),
              DropdownMenuItem<String?>(
                value: 'SI',
                child: Text('Sí, agregar descuento'),
              ),
              DropdownMenuItem<String?>(value: 'NO', child: Text('No')),
            ],
            onChanged: controller.saving
                ? null
                : controller.setAgregarDescuento,
            decoration: ProductoDialogUI.decor(
              label: '¿Agregar descuento?',
              hint: 'Seleccionar',
              prefixIcon: const Icon(Icons.local_offer_rounded),
            ),
          ),

          if (controller.descuentoEnabled) ...[
            ProductoDialogUI.gap(12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.descuentoTipo,
                    items: const [
                      DropdownMenuItem(
                        value: 'PORCENTAJE',
                        child: Text('PORCENTAJE'),
                      ),
                      DropdownMenuItem(value: 'MONTO', child: Text('MONTO')),
                    ],
                    onChanged: controller.saving
                        ? null
                        : (v) => controller.setDescuentoTipo(
                            v ?? controller.descuentoTipo,
                          ),
                    decoration: ProductoDialogUI.decor(
                      label: 'Tipo',
                      prefixIcon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.descuentoCtrl,
                    enabled: !controller.saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*([.,]\d{0,2})?$'),
                      ),
                    ],
                    decoration: ProductoDialogUI.decor(
                      label: controller.descuentoTipo == 'PORCENTAJE'
                          ? 'Valor (%)'
                          : 'Valor (Bs)',
                      prefixIcon: Icon(
                        controller.descuentoTipo == 'PORCENTAJE'
                            ? Icons.percent_rounded
                            : Icons.payments_rounded,
                      ),
                    ),
                    validator: (v) {
                      if (!controller.descuentoEnabled) return null;
                      final val = controller.parseDouble(v ?? '');
                      if (val <= 0) return 'Ingresa un valor > 0';
                      if (controller.descuentoTipo == 'PORCENTAJE' &&
                          val > 100) {
                        return 'Máximo 100%';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // ✅ Pregunta banner promo (sin campos extra)
            ProductoDialogUI.gap(12),
            _PromoBannerToggle(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _PromoBannerToggle extends StatelessWidget {
  const _PromoBannerToggle({required this.controller});

  final ProductoDialogController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
            ),
            child: Icon(
              Icons.confirmation_number_rounded, // 🎟️ ticket
              color: Palette.primary.withValues(alpha: 0.9),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '¿Agregar un banner de promoción?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Palette.ink,
                fontSize: 13,
              ),
            ),
          ),
          Switch(
            value: controller.promoBannerEnabled,
            activeThumbColor: Palette.primary,
            activeTrackColor: Palette.primary.withValues(alpha: 0.5),
            onChanged: controller.saving
                ? null
                : controller.setPromoBannerEnabled,
          ),
        ],
      ),
    );
  }
}
