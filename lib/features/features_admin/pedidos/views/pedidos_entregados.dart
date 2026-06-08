import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/pedidos_controller.dart';
import 'detalle_pedido.dart';
import 'widgets/depto_block.dart';
import 'widgets/micro_widgets.dart';
import 'widgets/stagger_in.dart';

class PedidosEntregadosPage extends StatefulWidget {
  const PedidosEntregadosPage({super.key});

  @override
  State<PedidosEntregadosPage> createState() => _PedidosEntregadosPageState();
}

class _PedidosEntregadosPageState extends State<PedidosEntregadosPage> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  final controller = PedidosController();

  @override
  void initState() {
    super.initState();

    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _q) return;
      setState(() => _q = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 760;

        return Scaffold(
          backgroundColor: Palette.card,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _EntregadosHeader(compact: compact, searchCtrl: _searchCtrl),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: controller.pedidosStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Error: ${snap.error}',
                            style: TextStyle(color: ink),
                          ),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: LoadingFancy(text: 'Cargando entregados…'),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    final idToDoc = {for (final d in docs) d.id: d};

                    final pedidos = docs.map((d) => controller.parsePedidoRow(d)).toList();

                    // ✅ esta page solo muestra los pedidos ya entregados
                    final filtered = controller.filterPedidos(
                      pedidos: pedidos,
                      query: _q,
                      estado: kEstadoEntregado,
                    );

                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(query: _q, estado: kEstadoEntregado),
                      );
                    }

                    final sections = controller.groupByDepartamento(filtered);

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      'Entregados',
                                      style: TextStyle(
                                        color: ink.withValues(alpha: 0.55),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CountPill(count: filtered.length),
                                    const Spacer(),
                                    if (!compact)
                                      const HintPill(text: 'Toca un pedido para ver detalle'),
                                  ],
                                ),
                              );
                            }

                            final s = sections[i - 1];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: DeptoBlock(
                                title: s.departamento,
                                count: s.pedidos.length,
                                children: List.generate(s.pedidos.length, (idx) {
                                  final p = s.pedidos[idx];
                                  final delay = math.min(420, (idx + i) * 18);

                                  return StaggerIn(
                                    delayMs: delay,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: idx == s.pedidos.length - 1 ? 0 : 10,
                                      ),
                                      child: PedidoCard(
                                        pedido: p,
                                        onTap: () async {
                                          final doc = idToDoc[p.id];
                                          if (doc == null) return;
                                          await showPedidoDetalleDialog(context, doc.id);
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                          childCount: sections.length + 1,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ================= HEADER ================= */

class _EntregadosHeader extends StatelessWidget {
  const _EntregadosHeader({required this.compact, required this.searchCtrl});

  final bool compact;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Palette.statsSuccess.withValues(alpha: 0.95),
            Palette.secondary.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entregados',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pedidos ya entregados por departamento',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                        hintText: compact
                            ? 'Buscar por código, dirección…'
                            : 'Buscar por código, dirección, uid o depto…',
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
      ),
    );
  }
}
