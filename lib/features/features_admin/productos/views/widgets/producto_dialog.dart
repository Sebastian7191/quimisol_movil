// lib/features/admin/productos/widgets/dialog/producto_dialog.dart
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/productos/controllers/producto_dialog_controller.dart' as ctrl;
import 'package:quimisol_movil/features/features_admin/productos/data/almacen_option.dart';
import 'package:quimisol_movil/features/features_admin/productos/data/unidad_option.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_form.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_preview_panel.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_top_bar.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_ui.dart';



class ProductoDialog extends StatefulWidget {
  final String title;
  final List<UnidadOption> unidades;
  final List<AlmacenOption> almacenes;

  final String? initialCodigo;
  final String? initialNombre;
  final String? initialDescripcion;
  final String? initialTipoItem;
  final String? initialUnidadId;
  final String? initialPrecio;
  final String? initialStock;

  final String? initialImagenUrl;
  final String? initialImagenPath;
  final String? initialAlmacenId;

  // ✅ NUEVO: categoría (para EDITAR)
  final String? initialCategoriaId;
  final String? initialCategoriaNombre;

  const ProductoDialog({
    super.key,
    required this.title,
    required this.unidades,
    required this.almacenes,
    this.initialCodigo,
    this.initialNombre,
    this.initialDescripcion,
    this.initialTipoItem,
    this.initialUnidadId,
    this.initialPrecio,
    this.initialStock,
    this.initialImagenUrl,
    this.initialImagenPath,
    this.initialAlmacenId,
    this.initialCategoriaId,
    this.initialCategoriaNombre,
  });

  @override
  State<ProductoDialog> createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<ProductoDialog> {
  final _formKey = GlobalKey<FormState>();

  /// ✅ ahora lo usamos como scroll GENERAL en móvil
  final ScrollController _scrollCtrl = ScrollController();

  late final ctrl.ProductoDialogController c;

  @override
  void initState() {
    super.initState();

    c = ctrl.ProductoDialogController(
      title: widget.title,
      initialImagenUrl: widget.initialImagenUrl ?? '',
      initialCodigo: widget.initialCodigo,
      initialNombre: widget.initialNombre,
      initialDescripcion: widget.initialDescripcion,
      initialTipoItem: widget.initialTipoItem,
      initialUnidadId: widget.initialUnidadId,
      initialPrecio: widget.initialPrecio,
      initialStock: widget.initialStock,
      initialAlmacenId: widget.initialAlmacenId,

      // ✅ NUEVO
      initialCategoriaId: widget.initialCategoriaId,
      initialCategoriaNombre: widget.initialCategoriaNombre,
    );

    // defaults si vienen null y hay listas
    if (c.unidadId == null && widget.unidades.isNotEmpty) {
      c.setUnidadId(widget.unidades.first.id);
    }
    if (c.almacenId == null && widget.almacenes.isNotEmpty) {
      c.setAlmacenId(widget.almacenes.first.id);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    c.dispose();
    super.dispose();
  }

  void _submit() {
    if (c.saving) return;
    if (widget.unidades.isEmpty || widget.almacenes.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;

    c.saving = true;

    final result = c.buildResult(
      unidades: widget.unidades,
      almacenes: widget.almacenes,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = (media.size.height * 0.92).clamp(520.0, 900.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1100, maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Palette.white,
            borderRadius: ProductoDialogUI.r18,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                ProductoDialogTopBar(
                  controller: c,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 14),

                /// ✅ CONTENIDO
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final isWide = box.maxWidth >= 980;

                      // ====== DESKTOP/TABLET (igual que antes) ======
                      if (isWide) {
                        final formScrollable = Scrollbar(
                          controller: _scrollCtrl,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.only(right: 6),
                            child: ProductoDialogForm(
                              formKey: _formKey,
                              controller: c,
                              unidades: widget.unidades,
                              almacenes: widget.almacenes,
                            ),
                          ),
                        );

                        final previewPanel = SizedBox(
                          width: 360,
                          child: ProductoDialogPreviewPanel(controller: c),
                        );

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: formScrollable),
                            const SizedBox(width: 14),
                            Align(
                              alignment: Alignment.topCenter,
                              child: previewPanel,
                            ),
                          ],
                        );
                      }

                      // ====== MÓVIL (FIX OVERFLOW) ======
                      // ✅ Un SOLO scroll que contiene:
                      //   1) formulario (arriba)
                      //   2) preview teléfono (abajo)
                      // ✅ botones quedan fijos abajo (fuera del scroll)
                      return Scrollbar(
                        controller: _scrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ProductoDialogForm(
                                formKey: _formKey,
                                controller: c,
                                unidades: widget.unidades,
                                almacenes: widget.almacenes,
                              ),
                              const SizedBox(height: 14),

                              // ✅ preview al final, abajo
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 380),
                                  child: ProductoDialogPreviewPanel(controller: c),
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                /// ✅ BOTONES (quedan fijos, ya no los tapa el teléfono)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: c.saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.ink,
                          side: BorderSide(
                            color: Palette.button.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: c.saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.button,
                          foregroundColor: Palette.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: c.saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
