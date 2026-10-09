// lib/features/admin/productos/widgets/dialog/widgets/producto_dialog_image_card.dart
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/productos/controllers/producto_dialog_controller.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_ui.dart';

class ProductoDialogImageCard extends StatelessWidget {
  const ProductoDialogImageCard({super.key, required this.controller});

  final ProductoDialogController controller;

  @override
  Widget build(BuildContext context) {
    // se actualiza cuando cambias imagen o url (previewTick)
    return ValueListenableBuilder<int>(
      valueListenable: controller.previewTick,
      builder: (_, __, ___) {
        final hasPicked = controller.pickedBytes != null;
        final hasUrl = controller.existingImageUrl.trim().isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: ProductoDialogUI.r16,
            border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.image_rounded, color: Palette.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Imagen del producto',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Palette.ink,
                    ),
                  ),
                  const Spacer(),
                  if (hasPicked || hasUrl)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.statsSuccess.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Palette.statsSuccess.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        hasPicked ? 'Nueva' : 'Actual',
                        style: TextStyle(
                          color: Palette.statsSuccess.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: ProductoDialogUI.r12,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hasPicked
                      ? Image.memory(controller.pickedBytes!, fit: BoxFit.cover)
                      : (hasUrl
                            ? Image.network(
                                controller.existingImageUrl,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) =>
                                    const EmptyImagePlaceholder(
                                      message: 'No se pudo cargar',
                                    ),
                              )
                            : const EmptyImagePlaceholder()),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.saving
                        ? null
                        : () => controller.pickImage(context),
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Seleccionar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.button,
                      foregroundColor: Palette.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed:
                        (controller.saving || controller.pickedBytes == null)
                        ? null
                        : controller.clearPickedImage,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Quitar nueva'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.ink,
                      side: BorderSide(
                        color: Palette.button.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
