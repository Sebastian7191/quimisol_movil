import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';

import '../controllers/unidades_controller.dart';

import 'widgets/dialogs/form_result.dart';
import 'widgets/dialogs/unidad_dialog.dart';
import 'widgets/un_empty_box.dart';
import 'widgets/un_error_box.dart';
import 'widgets/un_loading_table.dart';

class UnidadesPage extends StatefulWidget {
  const UnidadesPage({super.key});

  @override
  State<UnidadesPage> createState() => _UnidadesPageState();
}

class _UnidadesPageState extends State<UnidadesPage> {
  final controller = UnidadesController();

  @override
  void initState() {
    super.initState();
    // Rebuild UI when the controller's search text changes
    controller.searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _unidadesStream() =>
      controller.unidadesStream();

  Future<void> _openAddDialog() async {
    final res = await showDialog<UnidadFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UnidadDialog(title: 'Agregar unidad'),
    );

    if (res == null) return;

    try {
      await controller.crearUnidad(
        nombre: res.nombre,
        abreviatura: res.abreviatura,
        descripcion: res.descripcion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unidad agregada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar unidad: $e'),
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
    final res = await showDialog<UnidadFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UnidadDialog(
        title: 'Editar unidad',
        initialNombre: (data['nombre'] ?? '').toString(),
        initialAbreviatura: (data['abreviatura'] ?? '').toString(),
        initialDescripcion: (data['descripcion'] ?? '').toString(),
      ),
    );

    if (res == null) return;

    try {
      await controller.actualizarUnidad(
        id: id,
        nombre: res.nombre,
        abreviatura: res.abreviatura,
        descripcion: res.descripcion,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unidad actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar unidad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUnidad(String id, String nombre) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ConfirmDeleteDialog(
      title: 'Eliminar unidad',
      message: '¿Seguro que quieres eliminar "$nombre"?',
    ),
  );

  if (ok != true) return;

  try {
    await controller.eliminarUnidad(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad eliminada')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar unidad: $e'),
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
                          Icons.straighten_rounded,
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
                              'Gestión de Unidades',
                              style: TextStyle(
                                fontSize: compact ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                color: Palette.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Crea, edita y elimina unidades de medida',
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
                        label: Text(compact ? 'Agregar' : 'Agregar unidad'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.white.withValues(alpha: 0.18),
                          foregroundColor: Palette.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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

                  // ===== Buscador dentro del header =====
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
                              hintText: 'Buscar por nombre o abreviatura…',
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
              stream: _unidadesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return UnidadesErrorBox(
                    message: 'Error al cargar unidades: ${snapshot.error}',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const UnidadesLoadingTable();
                }

                final docs = snapshot.data?.docs ?? [];

                final filtered = controller.buildRows(docs);

                if (filtered.isEmpty) {
                  return const UnidadesEmptyBox(
                    title: 'No hay unidades',
                    subtitle: 'Agrega una unidad o ajusta tu búsqueda.',
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Palette.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
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
                          DataColumn(label: Text('Abrev.')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: filtered.map((r) {
                          final id = r['id'] as String;
                          final nombre = r['nombre'] as String;
                          final abrev = r['abreviatura'] as String;
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
                              DataCell(Text(abrev.isEmpty ? '-' : abrev)),
                              DataCell(
                                SizedBox(
                                  width: 420,
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
                                          'abreviatura': abrev,
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
                                      onPressed: () =>
                                          _deleteUnidad(id, nombre),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Palette.statsDanger.withValues(alpha: 
                                          0.95,
                                        ),
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