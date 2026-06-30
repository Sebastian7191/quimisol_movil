import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';
import 'package:quimisol_movil/shared/widgets/admin_action_button.dart';
import 'package:quimisol_movil/shared/widgets/pagination_bar.dart';

import '../controllers/categorias_controller.dart';
import '../widgets/dialogs/form_result.dart';
import '../widgets/dialogs/categoria_dialog.dart';
import '../widgets/cat_empty_box.dart';
import '../widgets/cat_error_box.dart';
import '../widgets/cat_loading_table.dart';

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final controller = CategoriasController();
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    controller.searchCtrl.addListener(() => setState(() => _currentPage = 0));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream() =>
      controller.categoriasStream();

  Future<void> _openAddDialog() async {
    final res = await showDialog<CategoriaFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CategoriaDialog(title: 'Agregar categoría'),
    );

    if (res == null) return;

    try {
      await controller.crearCategoria(
        nombre: res.nombre,
        descripcion: res.descripcion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría agregada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar categoría: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final res = await showDialog<CategoriaFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoriaDialog(
        title: 'Editar categoría',
        initialNombre: (data['nombre'] ?? '').toString(),
        initialDescripcion: (data['descripcion'] ?? '').toString(),
      ),
    );

    if (res == null) return;

    try {
      await controller.actualizarCategoria(
        id: id,
        nombre: res.nombre,
        descripcion: res.descripcion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar categoría: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategoria(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDeleteDialog(
        title: 'Eliminar categoría',
        message: '¿Seguro que quieres eliminar "$nombre"?',
      ),
    );

    if (ok != true) return;

    try {
      await controller.eliminarCategoria(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar categoría: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        final isMobile = w < 860;
        final compact = w < 720;

        return Scaffold(
          backgroundColor: Palette.card,

          // ✅ FAB pill en móvil
          floatingActionButton: null,

          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(w < 420 ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCategorias(
                    compact: compact,
                    onAdd: _openAddDialog,
                    searchCtrl: controller.searchCtrl,
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categoriasStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return CategoriasErrorBox(
                            message:
                                'Error al cargar categorías: ${snapshot.error}',
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CategoriasLoadingTable();
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final filtered = controller.buildRows(docs);

                        if (filtered.isEmpty) {
                          return const CategoriasEmptyBox(
                            title: 'No hay categorías',
                            subtitle:
                                'Agrega una categoría o ajusta tu búsqueda.',
                          );
                        }

                        final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 99999);
                        final page = _currentPage.clamp(0, totalPages - 1);
                        final pageItems = filtered.skip(page * _pageSize).take(_pageSize).toList();

                        final paginationBar = AdminPaginationBar(
                          currentPage: page,
                          totalItems: filtered.length,
                          pageSize: _pageSize,
                          onPrev: page > 0 ? () => setState(() => _currentPage = page - 1) : null,
                          onNext: (page + 1) * _pageSize < filtered.length ? () => setState(() => _currentPage = page + 1) : null,
                        );

                        // ✅ MOBILE: cards
                        if (isMobile) {
                          return Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  itemCount: pageItems.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final r = pageItems[i];
                                    final id = (r['id'] ?? '').toString();
                                    final nombre = (r['nombre'] ?? '').toString();
                                    final desc = (r['descripcion'] ?? '').toString();

                                    return _CategoriaCardMobile(
                                      nombre: nombre,
                                      descripcion: desc,
                                      onEdit: () => _openEditDialog(
                                        id: id,
                                        data: {
                                          'nombre': nombre,
                                          'descripcion': desc,
                                        },
                                      ),
                                      onDelete: () => _deleteCategoria(id, nombre),
                                    );
                                  },
                                ),
                              ),
                              paginationBar,
                            ],
                          );
                        }

                        // ✅ DESKTOP: DataTable
                        return Column(
                          children: [
                            Expanded(
                              child: Container(
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
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowHeight: 58,
                                        dataRowMinHeight: 62,
                                        dataRowMaxHeight: 80,
                                        columnSpacing: 18,
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16.5,
                                          color: Palette.ink,
                                        ),
                                        dataTextStyle: const TextStyle(
                                          fontSize: 16.5,
                                          color: Palette.ink,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('Nombre')),
                                          DataColumn(label: Text('Descripción')),
                                          DataColumn(label: Text('Acciones')),
                                        ],
                                        rows: pageItems.map((r) {
                                          final id = (r['id'] ?? '').toString();
                                          final nombre = (r['nombre'] ?? '').toString();
                                          final desc = (r['descripcion'] ?? '').toString();

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  nombre.isEmpty ? '-' : nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 520,
                                                  child: Text(
                                                    desc.isEmpty ? '-' : desc,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Palette.ink.withValues(
                                                        alpha: 0.85,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    AdminActionButton(
                                                      icon: Icons.edit_rounded,
                                                      color: Palette.primary,
                                                      tooltip: 'Editar',
                                                      onTap: () => _openEditDialog(
                                                        id: id,
                                                        data: {
                                                          'nombre': nombre,
                                                          'descripcion': desc,
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    AdminActionButton(
                                                      icon: Icons.delete_outline_rounded,
                                                      color: Palette.statsDanger,
                                                      tooltip: 'Eliminar',
                                                      onTap: () => _deleteCategoria(id, nombre),
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
                                ),
                              ),
                            ),
                            paginationBar,
                          ],
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
  }
}

// ===================== HEADER =====================

class _HeaderCategorias extends StatelessWidget {
  final bool compact;
  final VoidCallback onAdd;
  final TextEditingController searchCtrl;

  const _HeaderCategorias({
    required this.compact,
    required this.onAdd,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Palette.primary.withValues(alpha: 0.95),
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
      child: Column(
        children: [
          Row(
            children: [
              if (!compact) ...[
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
                    Icons.category_rounded,
                    color: Palette.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestión de Categorías',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15.5 : 19.5,
                        fontWeight: FontWeight.w900,
                        color: Palette.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea y administra categorías de productos',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14.5 : 16.5,
                        color: Palette.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(compact ? 'Agregar' : 'Agregar categoría'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: compact ? Palette.white : Palette.white.withValues(alpha: 0.18),
                  foregroundColor: compact ? Palette.primary : Palette.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 10 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 999 : 14),
                    side: compact ? BorderSide.none : const BorderSide(color: Palette.white, width: 2),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ Search dentro del header
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Palette.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ink.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: ink.withValues(alpha: 0.45)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o descripción…',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: ink.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchCtrl,
                  builder: (_, v, __) {
                    final has = v.text.trim().isNotEmpty;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: c),
                      child: !has
                          ? const SizedBox(width: 10, key: ValueKey('empty'))
                          : InkWell(
                              key: const ValueKey('clear'),
                              onTap: () => searchCtrl.clear(),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: ink.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== FAB PILL =====================


// ===================== MOBILE CARD =====================

class _CategoriaCardMobile extends StatelessWidget {
  const _CategoriaCardMobile({
    required this.nombre,
    required this.descripcion,
    required this.onEdit,
    required this.onDelete,
  });

  final String nombre;
  final String descripcion;

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Palette.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Palette.button.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Palette.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombre.trim().isEmpty ? '-' : nombre.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Palette.ink,
                      fontSize: 18.5,
                    ),
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
                  fontSize: 15.5,
                  height: 1.15,
                ),
              )
            else
              Text(
                'Sin descripción',
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminActionButtonMobile(
                    icon: Icons.edit_rounded,
                    color: Palette.primary,
                    label: 'Editar',
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AdminActionButtonMobile(
                    icon: Icons.delete_outline_rounded,
                    color: Palette.statsDanger,
                    label: 'Eliminar',
                    onPressed: onDelete,
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