import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/almacenes_controller.dart';

import 'widgets/dialogs/add_dialog.dart';
import 'widgets/dialogs/new_almacen_form.dart';
import 'widgets/al_empty.dart';
import 'widgets/al_error.dart';
import 'widgets/al_loading.dart';

class AlmacenesPage extends StatefulWidget {
  const AlmacenesPage({super.key});

  @override
  State<AlmacenesPage> createState() => _AlmacenesPageState();
}

class _AlmacenesPageState extends State<AlmacenesPage> {
  final controller = AlmacenesController();

  // IMPRIMIR LINK ÍNDICE EN CONSOLA
  void _printFirestoreIndexLink(Object error) {
    controller.printFirestoreIndexLink(error);
  }

  // Todo pal controller
  Future<void> _guardarAlmacenFirestore({
    required String nombre,
    required String departamento,
    required String descripcion,
  }) async {
    await controller.guardarAlmacen(
      nombre: nombre,
      departamento: departamento,
      descripcion: descripcion,
    );
  }

  Future<void> _openAddAlmacenDialog() async {
    final res = await showDialog<NewAlmacenFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddAlmacenDialog(),
    );

    if (res == null) return;

    try {
      await _guardarAlmacenFirestore(
        nombre: res.nombre,
        departamento: res.departamento,
        descripcion: res.descripcion,
      );

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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Streams delegados al controller
  Stream<QuerySnapshot<Map<String, dynamic>>> _almacenesStream() =>
      controller.almacenesStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _productosStream() =>
      controller.productosStream();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ================= HEADER (con filtro adentro) =================
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 720;

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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _openAddAlmacenDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(compact ? 'Agregar' : 'Agregar almacén'),
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

          // ================= FILTRO DEPARTAMENTOS (dentro del header) =================
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.departamentos.map((d) {
                        final selected = d == controller.selectedDepto;

                        return ChoiceChip(
                          label: Text(d),
                          selected: selected,
                          selectedColor: Palette.white.withValues(alpha: 0.22),
                          backgroundColor: Palette.white.withValues(alpha: 0.14),
                          side: BorderSide(
                            color: Palette.ink.withValues(alpha: selected ? 0.55 : 0.26),
                          ),
                          labelStyle: TextStyle(
                            color: Palette.ink.withValues(alpha: selected ? 1 : 0.92),
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) =>
                              setState(() => controller.selectedDepto = d),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ================= LISTADO DESDE FIRESTORE =================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _almacenesStream(),
              builder: (context, almacenesSnap) {
                if (almacenesSnap.hasError) {
                  _printFirestoreIndexLink(almacenesSnap.error!);
                  return AlmacenesErrorBox(
                    message:
                        'Error al cargar almacenes: ${almacenesSnap.error}',
                  );
                }

                if (almacenesSnap.connectionState == ConnectionState.waiting) {
                  return const AlmacenesLoadingGrid();
                }

                final almacenesDocs = almacenesSnap.data?.docs ?? [];

                // 2do stream: productos para calcular totales por almacén
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _productosStream(),
                  builder: (context, productosSnap) {
                    if (productosSnap.hasError) {
                      return AlmacenesErrorBox(
                        message:
                            'Error al cargar productos para conteo: ${productosSnap.error}',
                      );
                    }

                    if (productosSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const AlmacenesLoadingGrid();
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

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.6,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final a = filtered[i];

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Modular.to.pushNamed('/almacenes/${a['id']}');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Palette.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Palette.button.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 12,
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['nombre'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Palette.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a['departamento'] as String,
                                  style: TextStyle(
                                    color: Palette.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    _Stat(
                                      label: 'Productos',
                                      value: (a['productos'] ?? 0).toString(),
                                    ),
                                    const SizedBox(width: 16),
                                    _Stat(
                                      label: 'Stock',
                                      value: (a['stock'] ?? 0).toString(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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
      children: [
        Text(
          label,
          style: TextStyle(color: Palette.ink.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Palette.ink,
          ),
        ),
      ],
    );
  }
}