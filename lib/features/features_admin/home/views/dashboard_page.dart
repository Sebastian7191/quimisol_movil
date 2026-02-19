import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/dashboard_controller.dart';
import '../data/dashboard_firestore.dart';
import '../data/dashboard_models.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_filters.dart';
import 'widgets/dashboard_stat_cards.dart';
import 'widgets/dashboard_sections.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController c;
  late final DashboardFirestore repo;

  @override
  void initState() {
    super.initState();
    c = DashboardController();
    repo = DashboardFirestore(FirebaseFirestore.instance);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final from = c.rangeStart;

        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(width: w),
                  const SizedBox(height: 14),

                  // filtros (incluye almacenes desde Firestore)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: repo.almacenesStream(),
                    builder: (context, snapAlm) {
                      final almacenes = snapAlm.data?.docs ?? const [];
                      return DashboardFilters(
                        controller: c,
                        almacenes: almacenes,
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // Datos principales
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: repo.pedidosStream(
                      from: from,
                      estado: c.estado,
                      departamento: c.departamento,
                    ),
                    builder: (context, pedidosSnap) {
                      final pedidosDocs = pedidosSnap.data?.docs ?? const [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: repo.productosStream(almacenId: c.almacenId),
                        builder: (context, prodSnap) {
                          final prodDocs = prodSnap.data?.docs ?? const [];

                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: repo.usuariosStream(),
                            builder: (context, userSnap) {
                              final userDocs = userSnap.data?.docs ?? const [];

                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: repo.repartidoresStream(almacenId: c.almacenId),
                                builder: (context, repSnap) {
                                  final repDocs = repSnap.data?.docs ?? const [];

                                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: repo.bannersStream(),
                                    builder: (context, banSnap) {
                                      final banDocs = banSnap.data?.docs ?? const [];

                                      final stats = DashboardStats.build(
                                        pedidos: pedidosDocs,
                                        productos: prodDocs,
                                        usuarios: userDocs,
                                        repartidores: repDocs,
                                        banners: banDocs,
                                        rangeStart: from,
                                      );

                                      return Column(
                                        children: [
                                          DashboardStatCards(width: w, stats: stats),
                                          const SizedBox(height: 14),
                                          DashboardSections(width: w, stats: stats, range: c.range),
                                          const SizedBox(height: 22),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 22),
                  Text(
                    'Tip: si algún gráfico sale vacío, revisa el rango/filtros.',
                    style: TextStyle(
                      color: Palette.ink.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
