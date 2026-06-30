// lib/features/admin/productos/widgets/dialog/widgets/producto_dialog_top_bar.dart
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/productos/controllers/producto_dialog_controller.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_ui.dart';

class ProductoDialogTopBar extends StatelessWidget {
  const ProductoDialogTopBar({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final ProductoDialogController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.title.toLowerCase().contains('editar');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: ProductoDialogUI.r18,
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.button.withValues(alpha: 0.14),
            Palette.card.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.add_rounded,
              color: Palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Actualiza datos, inventario, descuento e imagen.'
                      : 'Completa los datos para registrar el producto.',
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: controller.saving ? null : onClose,
            icon: Icon(
              Icons.close_rounded,
              color: Palette.ink.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
