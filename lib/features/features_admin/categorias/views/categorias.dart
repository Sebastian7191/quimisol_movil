import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';


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

  @override
  void initState() {
    super.initState();
    controller.searchCtrl.addListener(() => setState(() {}));
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER (con buscador adentro) =================
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 720;
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestión de Categorías',
                                style: TextStyle(
                                  fontSize: compact ? 18 : 22,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Crea y administra categorías de productos',
                                style: TextStyle(
                                  fontSize: compact ? 12 : 13,
                                  color: Palette.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _openAddDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(compact ? 'Agregar' : 'Agregar categoría'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.white.withValues(alpha: 0.18),
                            foregroundColor: Palette.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Palette.white,
                                width: 2,
                              ),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ===== buscador dentro del header (como Usuarios/Unidades) =====
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
                                    Icon(
                                      Icons.search_rounded,
                                      color: ink.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: controller.searchCtrl,
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
                                      valueListenable: controller.searchCtrl,
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
                                                  onTap: () => controller.searchCtrl.clear(),
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
                      },
                    ),
                    const SizedBox(height: 16),

          // ================= LISTADO =================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _categoriasStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return CategoriasErrorBox(
                    message: 'Error al cargar categorías: ${snapshot.error}',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CategoriasLoadingTable();
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = controller.buildRows(docs);

                if (filtered.isEmpty) {
                  return const CategoriasEmptyBox(
                    title: 'No hay categorías',
                    subtitle: 'Agrega una categoría o ajusta tu búsqueda.',
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
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 72,
                        columnSpacing: 18,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                        ),
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: filtered.map((r) {
                          final id = r['id'] as String;
                          final nombre = r['nombre'] as String;
                          final desc = r['descripcion'] as String;

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
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      onPressed: () => _openEditDialog(
                                        id: id,
                                        data: {
                                          'nombre': nombre,
                                          'descripcion': desc,
                                        },
                                      ),
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        color: Palette.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      onPressed: () => _deleteCategoria(id, nombre),
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
    );
  }
}