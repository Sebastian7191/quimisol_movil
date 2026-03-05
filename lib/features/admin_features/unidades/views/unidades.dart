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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unidad actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar unidad: $e'),
            backgroundColor: Palette.statsDanger,
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

          // ✅ FAB pill en móvil (mejor UX)
          floatingActionButton: compact
              ? _FloatingAddPill(
                  enabled: true,
                  onTap: _openAddDialog,
                )
              : null,

          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(w < 420 ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderUnidades(
                    compact: compact,
                    onAdd: _openAddDialog,
                    searchCtrl: controller.searchCtrl,
                  ),
                  const SizedBox(height: 16),

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

                        // ✅ MOBILE: cards (mejor UX)
                        if (isMobile) {
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final r = filtered[i];
                              final id = (r['id'] ?? '').toString();
                              final nombre = (r['nombre'] ?? '').toString();
                              final abrev = (r['abreviatura'] ?? '').toString();
                              final desc = (r['descripcion'] ?? '').toString();

                              return _UnidadCardMobile(
                                nombre: nombre,
                                abreviatura: abrev,
                                descripcion: desc,
                                onEdit: () => _openEditDialog(
                                  id: id,
                                  data: {
                                    'nombre': nombre,
                                    'abreviatura': abrev,
                                    'descripcion': desc,
                                  },
                                ),
                                onDelete: () => _deleteUnidad(id, nombre),
                              );
                            },
                          );
                        }

                        // ✅ DESKTOP: DataTable
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
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
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
                                    final id = (r['id'] ?? '').toString();
                                    final nombre = (r['nombre'] ?? '').toString();
                                    final abrev = (r['abreviatura'] ?? '').toString();
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
                                        DataCell(Text(abrev.isEmpty ? '-' : abrev)),
                                        DataCell(
                                          SizedBox(
                                            width: 420,
                                            child: Text(
                                              desc.isEmpty ? '-' : desc,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Palette.ink.withValues(alpha: 0.85),
                                              ),
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
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                  color: Palette.primary,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Eliminar',
                                                onPressed: () => _deleteUnidad(id, nombre),
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
  }
}

// ===================== HEADER (responsive + search) =====================

class _HeaderUnidades extends StatelessWidget {
  final bool compact;
  final VoidCallback onAdd;
  final TextEditingController searchCtrl;

  const _HeaderUnidades({
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
                      'Crea, edita y elimina unidades de medida',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: Palette.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ En móvil no saturamos: el botón va flotante
              if (!compact) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Palette.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Palette.button.withValues(alpha: 0.95),
                        width: 2.6,
                      ),
                    ),
                    child: const _GradientIconText(compact: false, enabled: true),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ✅ Search dentro del header (rápido + limpio)
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
                  valueListenable: searchCtrl,
                  builder: (_, v, __) {
                    final has = v.text.trim().isNotEmpty;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
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
              color: Palette.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
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
            child: const _GradientIconText(compact: true, enabled: true),
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
            compact ? 'Agregar' : 'Agregar unidad',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ===================== MOBILE CARD =====================

class _UnidadCardMobile extends StatelessWidget {
  const _UnidadCardMobile({
    required this.nombre,
    required this.abreviatura,
    required this.descripcion,
    required this.onEdit,
    required this.onDelete,
  });

  final String nombre;
  final String abreviatura;
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
                    border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: Palette.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.trim().isEmpty ? '-' : nombre.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MiniInfoChip(label: 'Abrev.', value: abreviatura.trim().isEmpty ? '-' : abreviatura.trim()),
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