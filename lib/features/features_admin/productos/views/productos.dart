import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/productos/data/producto_dialog_result.dart';

import '../controllers/products_controller.dart';
import '../data/producto_row.dart';
import '../data/unidad_option.dart';
import '../data/almacen_option.dart';

import 'widgets/producto_dialog.dart';

import 'widgets/dialogs/img_viewer_dialog.dart';
import 'widgets/empty_box.dart';
import 'widgets/error_box.dart';
import 'widgets/loading_table.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  String _tipo = 'Todos'; // Todos | PRODUCTO | INSUMO

  final controller = ProductosController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _search = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _productosStream() {
    return controller.productosStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _unidadesStream() {
    return controller.unidadesStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _almacenesStream() {
    return controller.almacenesStream();
  }

  Future<void> _openAddDialog({
    required List<UnidadOption> unidades,
    required List<AlmacenOption> almacenes,
  }) async {
    if (almacenes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Primero crea al menos un almacén en la colección "almacenes".',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final res = await showDialog<ProductoDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductoDialog(
        title: 'Agregar producto',
        unidades: unidades,
        almacenes: almacenes,
      ),
    );

    if (res == null) return;

    try {
      await controller.crearProducto(
        res.producto,
        descuento: res.descuento,
        promoBannerEnabled: res.promoBannerEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog({
    required String id,
    required ProductoRow product,
    required List<UnidadOption> unidades,
    required List<AlmacenOption> almacenes,
  }) async {
    final res = await showDialog<ProductoDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductoDialog(
        title: 'Editar producto',
        unidades: unidades,
        almacenes: almacenes,
        initialCodigo: product.codigo,
        initialNombre: product.nombre,
        initialDescripcion: product.descripcion,
        initialTipoItem: product.tipoItem,
        initialUnidadId: product.unidadId,
        initialPrecio: product.precio.toString(),
        initialStock: product.stock.toString(),
        initialImagenUrl: product.imagenUrl,
        initialImagenPath: product.imagenPath,
        initialAlmacenId: product.almacenId,
      ),
    );

    if (res == null) return;

    try {
      await controller.actualizarProducto(
        id,
        res.producto,
        existingImagenUrl: product.imagenUrl,
        existingImagenPath: product.imagenPath,
        descuento: res.descuento,
        promoBannerEnabled: res.promoBannerEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProducto(
    String id,
    String nombre, {
    String? imagenPath,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Palette.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Eliminar producto',
          style: TextStyle(fontWeight: FontWeight.w900, color: Palette.ink),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "$nombre"?',
          style: TextStyle(color: Palette.ink.withValues(alpha: 0.85)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.statsDanger,
              foregroundColor: Palette.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await controller.eliminarProducto(id, imagenPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openImageViewer({
    required String title,
    required String imagenPath,
    required String imagenUrl,
  }) {
    showDialog(
      context: context,
      builder: (_) => ImageViewerDialog(
        title: title,
        imagenPath: imagenPath,
        imagenUrl: imagenUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _unidadesStream(),
      builder: (context, unidadesSnap) {
        if (unidadesSnap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorBox(
              message: 'Error al cargar unidades: ${unidadesSnap.error}',
            ),
          );
        }

        final unidadesDocs = unidadesSnap.data?.docs ?? [];
        final unidades = unidadesDocs.map((d) {
          final data = d.data();
          return UnidadOption(
            id: d.id,
            nombre: (data['nombre'] ?? '').toString(),
            abreviatura: (data['abreviatura'] ?? '').toString(),
          );
        }).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _almacenesStream(),
          builder: (context, almacenesSnap) {
            if (almacenesSnap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorBox(
                  message: 'Error al cargar almacenes: ${almacenesSnap.error}',
                ),
              );
            }

            final almacenesDocs = almacenesSnap.data?.docs ?? [];
            final almacenes = almacenesDocs
                .map((d) {
                  final data = d.data();
                  return AlmacenOption(
                    id: d.id,
                    nombre: (data['nombre'] ?? '').toString(),
                    activo:
                        (data['activo'] is bool) ? (data['activo'] as bool) : true,
                  );
                })
                .where((a) => a.activo)
                .toList();

            return LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final isMobile = w < 860;
                final compact = w < 720;

                final canAdd = !(unidades.isEmpty || almacenes.isEmpty);

                return Scaffold(
                  backgroundColor: Palette.card,

                  // ✅ FAB pill: SOLO bordes celestes (Palette.button)
                  floatingActionButton: compact
                      ? _FloatingAddPill(
                          enabled: canAdd,
                          onTap: canAdd
                              ? () => _openAddDialog(
                                    unidades: unidades,
                                    almacenes: almacenes,
                                  )
                              : null,
                        )
                      : null,

                  body: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(w < 420 ? 14 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderProductos(
                            compact: compact,
                            canAdd: canAdd,
                            onAdd: () => _openAddDialog(
                              unidades: unidades,
                              almacenes: almacenes,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _SearchBarProductos(controller: _searchCtrl),
                          const SizedBox(height: 12),

                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: const ['Todos', 'PRODUCTO', 'INSUMO'].length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final t = const ['Todos', 'PRODUCTO', 'INSUMO'][i];
                                final selected = _tipo == t;

                                return ChoiceChip(
                                  label: Text(t == 'Todos' ? 'Todos' : t),
                                  selected: selected,
                                  selectedColor: Palette.primary.withValues(alpha: 0.18),
                                  backgroundColor: Palette.white,
                                  side: BorderSide(
                                    color: selected
                                        ? Palette.primary.withValues(alpha: 0.55)
                                        : Palette.button.withValues(alpha: 0.35),
                                  ),
                                  labelStyle: TextStyle(
                                    color: Palette.ink.withValues(alpha: selected ? 1 : 0.9),
                                    fontWeight: FontWeight.w900,
                                  ),
                                  onSelected: (_) => setState(() => _tipo = t),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          Expanded(
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _productosStream(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return ErrorBox(
                                    message: 'Error al cargar productos: ${snapshot.error}',
                                  );
                                }

                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const LoadingTable(icon: Icons.inventory_2_rounded);
                                }

                                final docs = snapshot.data?.docs ?? [];
                                final productos =
                                    docs.map((d) => controller.mapProducto(d)).toList();

                                productos.sort((a, b) {
                                  final da = a.createdAt;
                                  final db = b.createdAt;
                                  if (da == null && db == null) return 0;
                                  if (da == null) return 1;
                                  if (db == null) return -1;
                                  return db.compareTo(da);
                                });

                                final filtered = controller.filterProductos(
                                  rows: productos,
                                  search: _search,
                                  tipo: _tipo,
                                );

                                if (filtered.isEmpty) {
                                  return const EmptyBox(
                                    title: 'No hay productos',
                                    subtitle: 'Agrega un producto o ajusta tus filtros.',
                                    icon: Icons.inventory_2_rounded,
                                  );
                                }

                                if (isMobile) {
                                  return ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 96),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final p = filtered[i];

                                      final id = p.id;
                                      final nombre = p.nombre;
                                      final imagenUrl = p.imagenUrl.trim();
                                      final imagenPath = p.imagenPath.trim();

                                      return _ProductoCardMobile(
                                        nombre: nombre,
                                        codigo: p.codigo,
                                        tipoItem: p.tipoItem,
                                        unidadNombre: p.unidadNombre,
                                        descripcion: p.descripcion,
                                        stock: p.stock,
                                        precio: p.precio,
                                        imagenUrl: imagenUrl,
                                        onTapImage: (imagenPath.isEmpty && imagenUrl.isEmpty)
                                            ? null
                                            : () => _openImageViewer(
                                                  title: nombre,
                                                  imagenPath: imagenPath,
                                                  imagenUrl: imagenUrl,
                                                ),
                                        onEdit: () => _openEditDialog(
                                          id: id,
                                          product: p,
                                          unidades: unidades,
                                          almacenes: almacenes,
                                        ),
                                        onDelete: () => _deleteProducto(
                                          id,
                                          nombre,
                                          imagenPath: imagenPath,
                                        ),
                                      );
                                    },
                                  );
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Palette.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Palette.button.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowHeight: 52,
                                        dataRowMinHeight: 64,
                                        dataRowMaxHeight: 84,
                                        columnSpacing: 18,
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Palette.ink,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('Imagen')),
                                          DataColumn(label: Text('Código')),
                                          DataColumn(label: Text('Nombre')),
                                          DataColumn(label: Text('Descripción')),
                                          DataColumn(label: Text('Tipo')),
                                          DataColumn(label: Text('Unidad')),
                                          DataColumn(label: Text('Stock')),
                                          DataColumn(label: Text('Precio')),
                                          DataColumn(label: Text('Acciones')),
                                        ],
                                        rows: filtered.map((p) {
                                          final id = p.id;
                                          final nombre = p.nombre;
                                          final tipoItem = p.tipoItem;
                                          final unidadNombre = p.unidadNombre;
                                          final desc = p.descripcion;
                                          final stock = p.stock;
                                          final precio = p.precio;
                                          final imagenUrl = p.imagenUrl.trim();
                                          final imagenPath = p.imagenPath.trim();

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                InkWell(
                                                  onTap: (imagenPath.isEmpty && imagenUrl.isEmpty)
                                                      ? null
                                                      : () => _openImageViewer(
                                                            title: nombre,
                                                            imagenPath: imagenPath,
                                                            imagenUrl: imagenUrl,
                                                          ),
                                                  child: _ProductoThumb(
                                                    imagenPath: imagenPath,
                                                    imagenUrl: imagenUrl,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  p.codigo.isEmpty ? '-' : p.codigo,
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 240,
                                                  child: Text(
                                                    nombre.isEmpty ? '-' : nombre,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 320,
                                                  child: Text(
                                                    desc.trim().isEmpty ? '-' : desc.trim(),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Palette.ink.withValues(alpha: 0.85),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(_ChipTipo(tipoItem: tipoItem)),
                                              DataCell(Text(unidadNombre.isEmpty ? '-' : unidadNombre)),
                                              DataCell(Text(stock.toString())),
                                              DataCell(Text(precio.toStringAsFixed(2))),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Editar',
                                                      onPressed: () => _openEditDialog(
                                                        id: id,
                                                        product: p,
                                                        unidades: unidades,
                                                        almacenes: almacenes,
                                                      ),
                                                      icon: Icon(Icons.edit_rounded, color: Palette.primary),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Eliminar',
                                                      onPressed: () => _deleteProducto(
                                                        id,
                                                        nombre,
                                                        imagenPath: imagenPath,
                                                      ),
                                                      icon: Icon(
                                                        Icons.delete_outline_rounded,
                                                        color: Palette.statsDanger.withValues(alpha: 0.95),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ===================== BOTÓN PILL (FAB) =====================

class _FloatingAddPill extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _FloatingAddPill({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // ✅ un solo fondo
              color: Palette.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              // ✅ solo borde celeste
              border: Border.all(
                color: Palette.button.withValues(alpha: 0.95),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _GradientIconText(compact: true, enabled: enabled),
          ),
        ),
      ),
    );
  }
}

class _GradientIconText extends StatelessWidget {
  final bool compact;
  final bool enabled;

  const _GradientIconText({required this.compact, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Palette.gradientStart.withValues(alpha: enabled ? 1 : 0.55),
        Palette.secondary.withValues(alpha: enabled ? 1 : 0.55),
      ],
    );

    return ShaderMask(
      shaderCallback: (rect) => gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, size: 20),
          const SizedBox(width: 8),
          Text(
            compact ? 'Agregar' : 'Agregar producto',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== HEADER =====================

class _HeaderProductos extends StatelessWidget {
  final bool compact;
  final bool canAdd;
  final VoidCallback onAdd;

  const _HeaderProductos({
    required this.compact,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Palette.gradientStart.withValues(alpha: 0.95),
            Palette.secondary.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Palette.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.white.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Palette.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de Productos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: Palette.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Administra productos e insumos rápidamente',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Palette.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ✅ botón del header: solo borde celeste + texto degradado
          if (!compact)
            InkWell(
              onTap: canAdd ? onAdd : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: canAdd ? 1 : 0.55,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Palette.white.withValues(alpha: 0.22), // leve, para que no "corte"
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Palette.button.withValues(alpha: 0.90),
                      width: 2.4,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Palette.white.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Palette.button.withValues(alpha: 0.22),
                        width: 1.4,
                      ),
                    ),
                    child: _GradientIconText(compact: false, enabled: canAdd),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===================== SEARCH BAR =====================

class _SearchBarProductos extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBarProductos({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Palette.ink.withValues(alpha: 0.45)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre…',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: const TextStyle(
                color: Palette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) {
              final has = v.text.trim().isNotEmpty;
              if (!has) return const SizedBox(width: 10);
              return InkWell(
                onTap: () => controller.clear(),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ===================== RESTO DE WIDGETS =====================

class _ChipTipo extends StatelessWidget {
  final String tipoItem;
  const _ChipTipo({required this.tipoItem});

  @override
  Widget build(BuildContext context) {
    final isProducto = tipoItem == 'PRODUCTO';
    final bg = isProducto
        ? Palette.statsSuccess.withValues(alpha: 0.15)
        : Palette.statsWarning.withValues(alpha: 0.18);
    final fg = isProducto ? Palette.statsSuccess : Palette.statsWarning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        tipoItem,
        style: TextStyle(
          color: fg.withValues(alpha: 0.95),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProductoThumb extends StatelessWidget {
  final String imagenPath;
  final String imagenUrl;

  const _ProductoThumb({required this.imagenPath, required this.imagenUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, color: Palette.ink.withValues(alpha: 0.35)),
      ),
    );

    final url = imagenUrl.trim();
    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

// =================== MOBILE CARD ===================

class _ProductoCardMobile extends StatelessWidget {
  const _ProductoCardMobile({
    required this.nombre,
    required this.codigo,
    required this.tipoItem,
    required this.unidadNombre,
    required this.descripcion,
    required this.stock,
    required this.precio,
    required this.imagenUrl,
    required this.onTapImage,
    required this.onEdit,
    required this.onDelete,
  });

  final String nombre;
  final String codigo;
  final String tipoItem;
  final String unidadNombre;
  final String descripcion;
  final int stock;
  final double precio;
  final String imagenUrl;

  final VoidCallback? onTapImage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onTapImage,
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 74,
                      height: 74,
                      child: imagenUrl.trim().isEmpty
                          ? Container(
                              color: Palette.fieldBg,
                              child: Icon(
                                Icons.image_outlined,
                                color: Palette.ink.withValues(alpha: 0.25),
                              ),
                            )
                          : Image.network(
                              imagenUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Palette.fieldBg,
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: Palette.statsDanger.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (nombre.trim().isEmpty ? '-' : nombre.trim()),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                          fontSize: 14.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (codigo.trim().isNotEmpty)
                            Flexible(
                              child: Text(
                                'Código: $codigo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Palette.ink.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (codigo.trim().isNotEmpty) const SizedBox(width: 8),
                          _ChipTipo(tipoItem: tipoItem),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (descripcion.trim().isNotEmpty)
              Text(
                descripcion.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.15,
                ),
              )
            else
              Text(
                'Sin descripción',
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _MiniInfoChip(label: 'Unidad', value: unidadNombre.isEmpty ? '-' : unidadNombre),
                _MiniInfoChip(label: 'Stock', value: stock.toString()),
                _MiniInfoChip(label: 'Precio', value: 'Bs ${precio.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.primary,
                      side: BorderSide(color: Palette.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.statsDanger.withValues(alpha: 0.95),
                      side: BorderSide(color: Palette.statsDanger.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.65),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Palette.ink,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}