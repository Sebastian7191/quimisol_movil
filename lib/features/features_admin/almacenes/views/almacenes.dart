import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/widgets/admin_action_button.dart';
import 'package:quimisol_movil/shared/widgets/pagination_bar.dart';

import '../controllers/almacenes_controller.dart';

import 'widgets/al_empty.dart';
import 'widgets/al_error.dart';
import 'widgets/al_loading.dart';

import 'widgets/dialogs/add_dialog.dart';
import 'widgets/dialogs/new_almacen_form.dart';
import 'widgets/dialogs/almacen_detail_dialog.dart';

const String kAlmacenesCollection = 'almacenes';

class AlmacenesPage extends StatefulWidget {
  const AlmacenesPage({super.key});

  @override
  State<AlmacenesPage> createState() => _AlmacenesPageState();
}

class _AlmacenesPageState extends State<AlmacenesPage> {
  final controller = AlmacenesController();
  int _currentPage = 0;
  static const int _pageSize = 12;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _cachedAlmacenesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _cachedProductosStream;

  @override
  void initState() {
    super.initState();
    _cachedAlmacenesStream = controller.almacenesStream();
    _cachedProductosStream = controller.productosStream();
  }

  void _printFirestoreIndexLink(Object error) {
    controller.printFirestoreIndexLink(error);
  }

  // Firestore ref (solo para UPDATE/DELETE)
  CollectionReference<Map<String, dynamic>> get _almRef =>
      FirebaseFirestore.instance.collection(kAlmacenesCollection);

  int _colsForWidth(double w) {
    if (w < 420) return 1;
    if (w < 760) return 2;
    return 3;
  }

  double _aspectForWidth(double w) {
    if (w < 420) return 2.05;
    if (w < 760) return 1.75;
    return 1.55;
  }

  // ---------------------------
  // CREATE (usa tu controller)
  // ---------------------------
  Future<void> _createAlmacen(NewAlmacenFormResult res) async {
    await controller.guardarAlmacen(
      nombre: res.nombre,
      departamento: res.departamento,
      descripcion: res.descripcion,
    );
  }

  // ---------------------------
  // UPDATE / DELETE (Firestore directo)
  // ---------------------------
  Future<void> _updateAlmacen(String id, NewAlmacenFormResult res) async {
    await _almRef.doc(id).set(
      {
        'nombre': res.nombre.trim(),
        'departamento': res.departamento.trim(),
        'descripcion': res.descripcion.trim(),
        'last_update': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _deleteAlmacen(String id) async {
    await _almRef.doc(id).delete();
  }

  // ---------------------------
  // Dialogs
  // ---------------------------
  void _openDetailDialog(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (_) => AlmacenDetailDialog(
        almacenId: (a['id'] ?? '').toString(),
        nombre: (a['nombre'] ?? '').toString(),
        departamento: (a['departamento'] ?? '').toString(),
      ),
    );
  }

  Future<void> _openAddAlmacenDialog() async {
    final res = await showDialog<NewAlmacenFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddAlmacenDialog(
        title: 'Agregar almacén',
        primaryActionText: 'Guardar',
      ),
    );

    if (res == null) return;

    try {
      await _createAlmacen(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Almacén agregado correctamente')),
        );
      }
    } catch (e) {
      debugPrint('Error guardando almacén: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar almacén: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  Future<void> _openEditAlmacenDialog(Map<String, dynamic> a) async {
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;

    final res = await showDialog<NewAlmacenFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddAlmacenDialog(
        title: 'Editar almacén',
        primaryActionText: 'Guardar',
        initialNombre: (a['nombre'] ?? '').toString(),
        initialDepartamento: (a['departamento'] ?? '').toString(),
        initialDescripcion: (a['descripcion'] ?? '').toString(),
        // si quieres usar tu lista del controller:
        departamentos: controller.departamentos
            .where((d) => d != 'Todos')
            .toList(),
      ),
    );

    if (res == null) return;

    try {
      await _updateAlmacen(id, res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
      }
    } catch (e) {
      debugPrint('Error editando almacén: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al editar: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> a) async {
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;

    final nombre = (a['nombre'] ?? 'este almacén').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar almacén'),
        content: Text(
          '¿Seguro que deseas eliminar "$nombre"?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.statsDanger,
              foregroundColor: Palette.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _deleteAlmacen(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Almacén eliminado')),
        );
      }
    } catch (e) {
      debugPrint('Error eliminando almacén: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  // ---------------------------
  // Bottom sheet de acciones
  // ---------------------------
  void _openActionsSheet(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Palette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final nombre = (a['nombre'] ?? '').toString();
        final depto = (a['departamento'] ?? '').toString();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.warehouse_rounded,
                        color: Palette.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre.isEmpty ? 'Almacén' : nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            depto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Palette.ink.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SheetAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Ver detalle',
                  onTap: () {
                    Navigator.pop(context);
                    _openDetailDialog(a);
                  },
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  onTap: () {
                    Navigator.pop(context);
                    _openEditAlmacenDialog(a);
                  },
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Eliminar',
                  danger: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(a);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = _colsForWidth(w);
    final aspect = _aspectForWidth(w);

    return Scaffold(
      backgroundColor: Palette.card,
      floatingActionButton: w < 720
          ? FloatingActionButton.extended(
              onPressed: _openAddAlmacenDialog,
              backgroundColor: Palette.primary,
              foregroundColor: Palette.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Agregar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(w < 420 ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderAlmacenes(
                compact: w < 720,
                onAdd: _openAddAlmacenDialog,
              ),
              const SizedBox(height: 12),

              // Filtro horizontal (mejor UX en móvil)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.departamentos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final d = controller.departamentos[i];
                    final selected = d == controller.selectedDepto;

                    return ChoiceChip(
                      label: Text(d),
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
                      onSelected: (_) => setState(() {
                        controller.selectedDepto = d;
                        _currentPage = 0;
                      }),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _cachedAlmacenesStream,
                  builder: (context, almacenesSnap) {
                    if (almacenesSnap.hasError) {
                      _printFirestoreIndexLink(almacenesSnap.error!);
                      return AlmacenesErrorBox(
                        message: 'Error al cargar almacenes: ${almacenesSnap.error}',
                      );
                    }

                    if (almacenesSnap.connectionState ==
                        ConnectionState.waiting) {
                      return AlmacenesLoadingGrid(columns: cols, aspect: aspect);
                    }

                    final almacenesDocs = almacenesSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _cachedProductosStream,
                      builder: (context, productosSnap) {
                        if (productosSnap.hasError) {
                          return AlmacenesErrorBox(
                            message:
                                'Error al cargar productos para conteo: ${productosSnap.error}',
                          );
                        }

                        if (productosSnap.connectionState ==
                            ConnectionState.waiting) {
                          return AlmacenesLoadingGrid(
                              columns: cols, aspect: aspect);
                        }

                        final productosDocs = productosSnap.data?.docs ?? [];
                        final filtered = controller.buildAlmacenesList(
                          almacenesDocs,
                          productosDocs,
                        );

                        if (filtered.isEmpty) {
                          return const AlmacenesEmptyBox(
                            title: 'No hay almacenes',
                            subtitle:
                                'Agrega un almacén o cambia el filtro de departamento.',
                          );
                        }

                        final maxStock = filtered
                            .map((e) => (e['stock'] ?? 0) as int)
                            .fold<int>(0, (p, c) => math.max(p, c));

                        final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 99999);
                        final page = _currentPage.clamp(0, totalPages - 1);
                        final pageItems = filtered.skip(page * _pageSize).take(_pageSize).toList();

                        return Column(
                          children: [
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.only(bottom: 8),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: aspect,
                                ),
                                itemCount: pageItems.length,
                                itemBuilder: (_, i) {
                                  final a = pageItems[i];
                                  return _AlmacenCard(
                                    data: a,
                                    maxStock: maxStock,
                                    onOpen: () => _openDetailDialog(a),
                                    onActions: () => _openActionsSheet(a),
                                  );
                                },
                              ),
                            ),
                            AdminPaginationBar(
                              currentPage: page,
                              totalItems: filtered.length,
                              pageSize: _pageSize,
                              onPrev: page > 0 ? () => setState(() => _currentPage = page - 1) : null,
                              onNext: (page + 1) * _pageSize < filtered.length ? () => setState(() => _currentPage = page + 1) : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== UI =====================

class _HeaderAlmacenes extends StatelessWidget {
  final bool compact;
  final VoidCallback onAdd;

  const _HeaderAlmacenes({
    required this.compact,
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
              border: Border.all(
                color: Palette.white.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
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
                  'Gestión de Almacenes',
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: Palette.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Administra almacenes por departamento',
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
          if (!compact)
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar almacén'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.white.withValues(alpha: 0.18),
                foregroundColor: Palette.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Palette.white, width: 2),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlmacenCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int maxStock;
  final VoidCallback onOpen;
  final VoidCallback onActions;

  const _AlmacenCard({
    required this.data,
    required this.maxStock,
    required this.onOpen,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (data['nombre'] ?? '').toString();
    final depto = (data['departamento'] ?? '').toString();
    final productos = (data['productos'] ?? 0) as int;
    final stock = (data['stock'] ?? 0) as int;

    final ratio = maxStock <= 0 ? 0.0 : (stock / maxStock).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(stock: stock),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    depto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barra visual (stock relativo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: Palette.card,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stock <= 0 ? Palette.statsDanger : Palette.statsSuccess,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _Stat(label: 'Productos', value: productos.toString()),
                      _Stat(label: 'Stock', value: stock.toString()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AdminActionButton(
                  icon: Icons.more_horiz_rounded,
                  color: Palette.ink,
                  tooltip: 'Acciones',
                  onTap: onActions,
                ),
                AdminActionButton(
                  icon: Icons.chevron_right_rounded,
                  color: Palette.primary,
                  tooltip: 'Ver',
                  onTap: onOpen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Palette.statsDanger : Palette.ink;
    final bg = (danger ? Palette.statsDanger : Palette.primary)
        .withValues(alpha: 0.06);
    final br = (danger ? Palette.statsDanger : Palette.primary)
        .withValues(alpha: 0.18);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: br),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int stock;
  const _StatusChip({required this.stock});

  @override
  Widget build(BuildContext context) {
    final isZero = stock <= 0;
    final base = isZero ? Palette.statsDanger : Palette.statsSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.25)),
      ),
      child: Text(
        isZero ? 'Sin stock' : 'OK',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: base,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Palette.ink,
          ),
        ),
      ],
    );
  }
}
