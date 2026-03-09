import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quimisol_movil/features/features_admin/productos/controllers/producto_dialog_controller.dart';
import 'package:quimisol_movil/features/features_admin/productos/data/almacen_option.dart';
import 'package:quimisol_movil/features/features_admin/productos/data/unidad_option.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_discount_block.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_image_card.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/widgets/dialogs/producto_dialog_ui.dart';

class ProductoDialogForm extends StatelessWidget {
  const ProductoDialogForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.unidades,
    required this.almacenes,
  });

  final GlobalKey<FormState> formKey;
  final ProductoDialogController controller;
  final List<UnidadOption> unidades;
  final List<AlmacenOption> almacenes;

  Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream() {
    return FirebaseFirestore.instance.collection('categorias').snapshots();
  }

  Widget _twoColResponsive(
    BuildContext context, {
    required Widget left,
    required Widget right,
    double breakpoint = 560,
    double gap = 12,
  }) {
    return LayoutBuilder(
      builder: (_, c) {
        final isNarrow = c.maxWidth < breakpoint;
        if (isNarrow) {
          return Column(
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            SizedBox(width: gap),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _ellipsisItem(String text) {
    return SizedBox(
      width: double.infinity,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Form(
          key: formKey,
          child: Column(
            children: [
              ProductoDialogUI.sectionTitle(
                title: 'Datos generales',
                subtitle: 'Almacén, categoría, unidad, contenido, tipo, código y nombre.',
                icon: Icons.badge_rounded,
              ),
              ProductoDialogUI.gap(12),

              ProductoDialogUI.card(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: controller.almacenId,
                      items: almacenes
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: _ellipsisItem(a.label),
                            ),
                          )
                          .toList(),
                      onChanged: controller.saving
                          ? null
                          : controller.setAlmacenId,
                      decoration: ProductoDialogUI.decor(
                        label: 'Almacén',
                        prefixIcon: const Icon(Icons.warehouse_rounded),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona un almacén'
                          : null,
                    ),

                    ProductoDialogUI.gap(),

                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categoriasStream(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            'Error al cargar categorías: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        }

                        if (snap.connectionState == ConnectionState.waiting) {
                          return DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: controller.categoriaId,
                            items: const [],
                            onChanged: null,
                            decoration: ProductoDialogUI.decor(
                              label: 'Categoría',
                              hint: 'Cargando...',
                              prefixIcon: const Icon(Icons.category_rounded),
                            ),
                          );
                        }

                        final docs = snap.data?.docs ?? [];
                        final categorias = docs
                            .map((d) {
                              final data = d.data();
                              return {
                                'id': d.id,
                                'nombre': (data['nombre'] ?? '')
                                    .toString()
                                    .trim(),
                              };
                            })
                            .where(
                              (c) => (c['nombre'] ?? '')
                                  .toString()
                                  .isNotEmpty,
                            )
                            .toList();

                        if (categorias.isEmpty) {
                          return DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: null,
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('— Sin categorías —'),
                              ),
                            ],
                            onChanged: null,
                            decoration: ProductoDialogUI.decor(
                              label: 'Categoría',
                              hint: 'Crea una categoría primero',
                              prefixIcon: const Icon(Icons.category_rounded),
                            ),
                          );
                        }

                        final existsSelected =
                            controller.categoriaId != null &&
                            categorias.any(
                              (c) => c['id'] == controller.categoriaId,
                            );

                        final selectedId = existsSelected
                            ? controller.categoriaId
                            : null;

                        return DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: selectedId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('— Seleccionar —'),
                            ),
                            ...categorias.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c['id'] as String,
                                child: _ellipsisItem(c['nombre'] as String),
                              ),
                            ),
                          ],
                          onChanged: controller.saving
                              ? null
                              : (id) {
                                  if (id == null) {
                                    controller.setCategoria(null, null);
                                    return;
                                  }
                                  final cat = categorias.firstWhere(
                                    (c) => c['id'] == id,
                                  );
                                  controller.setCategoria(
                                    id,
                                    (cat['nombre'] ?? '').toString(),
                                  );
                                },
                          decoration: ProductoDialogUI.decor(
                            label: 'Categoría',
                            prefixIcon: const Icon(Icons.category_rounded),
                            hint: 'Selecciona una categoría',
                          ),
                        );
                      },
                    ),

                    ProductoDialogUI.gap(),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: controller.unidadId,
                      items: unidades
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: _ellipsisItem(u.label),
                            ),
                          )
                          .toList(),
                      onChanged: controller.saving
                          ? null
                          : controller.setUnidadId,
                      decoration: ProductoDialogUI.decor(
                        label: 'Unidad',
                        prefixIcon: const Icon(Icons.straighten_rounded),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona una unidad'
                          : null,
                    ),

                    ProductoDialogUI.gap(),

                    TextFormField(
                      controller: controller.contenidoCtrl,
                      enabled: !controller.saving,
                      decoration: ProductoDialogUI.decor(
                        label: controller.contenidoLabel,
                        hint: controller.contenidoHint,
                        prefixIcon: Icon(
                          controller.categoriaEsBotella
                              ? Icons.local_drink_rounded
                              : Icons.inventory_2_rounded,
                        ),
                        helper: controller.contenidoHelper,
                      ),
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (text.isEmpty) {
                          return 'Ingresa ${controller.contenidoLabel.toLowerCase()}';
                        }
                        if (text.length < 2) return 'Valor inválido';
                        return null;
                      },
                    ),

                    ProductoDialogUI.gap(),

                    _twoColResponsive(
                      context,
                      left: TextFormField(
                        controller: controller.codigoCtrl,
                        enabled: !controller.saving,
                        decoration: ProductoDialogUI.decor(
                          label: 'Código',
                          hint: 'Opcional',
                          prefixIcon: const Icon(Icons.qr_code_rounded),
                        ),
                      ),
                      right: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: controller.tipoItem,
                        items: const [
                          DropdownMenuItem(
                            value: 'PRODUCTO',
                            child: Text('PRODUCTO'),
                          ),
                          DropdownMenuItem(
                            value: 'INSUMO',
                            child: Text('INSUMO'),
                          ),
                        ],
                        onChanged: controller.saving
                            ? null
                            : (v) => controller.setTipoItem(
                                  v ?? controller.tipoItem,
                                ),
                        decoration: ProductoDialogUI.decor(
                          label: 'Tipo',
                          prefixIcon: const Icon(Icons.category_rounded),
                        ),
                      ),
                    ),

                    ProductoDialogUI.gap(),

                    TextFormField(
                      controller: controller.nombreCtrl,
                      enabled: !controller.saving,
                      decoration: ProductoDialogUI.decor(
                        label: 'Nombre',
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa un nombre';
                        }
                        if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              ProductoDialogUI.gap(14),

              ProductoDialogUI.sectionTitle(
                title: 'Inventario',
                subtitle: 'Stock y precio.',
                icon: Icons.inventory_rounded,
              ),
              ProductoDialogUI.gap(12),

              ProductoDialogUI.card(
                child: Column(
                  children: [
                    TextFormField(
                      controller: controller.stockCtrl,
                      enabled: !controller.saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: ProductoDialogUI.decor(
                        label: 'Stock',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        helper: 'Solo enteros (ej: 0, 5, 12).',
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Solo enteros';
                        if (n < 0) return 'No puede ser negativo';
                        return null;
                      },
                    ),

                    ProductoDialogUI.gap(),

                    TextFormField(
                      controller: controller.precioCtrl,
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
                        label: 'Precio (Bs)',
                        prefixIcon: const Icon(Icons.payments_rounded),
                        helper: 'Admite decimales (ej: 10.5 o 10,50).',
                      ),
                      validator: (v) {
                        final p = controller.parsePrecio(v ?? '');
                        if (p < 0) return 'No puede ser negativo';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              ProductoDialogUI.gap(14),

              ProductoDialogUI.sectionTitle(
                title: 'Descuento',
                subtitle: 'Opcional: configura una promo para este producto.',
                icon: Icons.local_offer_rounded,
              ),
              ProductoDialogUI.gap(12),
              ProductoDialogDiscountBlock(controller: controller),

              ProductoDialogUI.gap(14),

              ProductoDialogUI.sectionTitle(
                title: 'Descripción',
                subtitle: 'Opcional: útil para detallar el producto.',
                icon: Icons.subject_rounded,
              ),
              ProductoDialogUI.gap(12),

              ProductoDialogUI.card(
                child: TextFormField(
                  controller: controller.descCtrl,
                  enabled: !controller.saving,
                  minLines: 4,
                  maxLines: 6,
                  decoration: ProductoDialogUI.decor(
                    label: 'Descripción',
                    hint: 'Ej: características, uso, contenido...',
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
              ),

              ProductoDialogUI.gap(14),

              ProductoDialogUI.sectionTitle(
                title: 'Imagen',
                subtitle: 'Opcional: puedes subir una foto para el catálogo.',
                icon: Icons.image_rounded,
              ),
              ProductoDialogUI.gap(12),
              ProductoDialogImageCard(controller: controller),

              ProductoDialogUI.gap(16),
            ],
          ),
        );
      },
    );
  }
}