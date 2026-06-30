import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/widgets/pagination_bar.dart';

import '../controllers/pedidos_controller.dart';
import 'detalle_pedido.dart';
import 'widgets/micro_widgets.dart';
import 'widgets/stagger_in.dart';

class PedidosEntregadosPage extends StatefulWidget {
  const PedidosEntregadosPage({super.key});

  @override
  State<PedidosEntregadosPage> createState() => _PedidosEntregadosPageState();
}

class _PedidosEntregadosPageState extends State<PedidosEntregadosPage>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _q = '';
  int _currentPage = 0;
  static const int _pageSize = 10;

  final controller = PedidosController();
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _q) return;
      setState(() {
        _q = v;
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 520;

    return Scaffold(
      backgroundColor: Palette.card,
      body: SafeArea(
        child: Column(
          children: [
            _EntregadosHeader(
              compact: compact,
              bgCtrl: _bgCtrl,
              searchCtrl: _searchCtrl,
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: controller.pedidosStream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: TextStyle(color: ink),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const LoadingFancy(text: 'Cargando entregados…');
                  }

                  final docs = snap.data?.docs ?? [];
                  final idToDoc = {for (final d in docs) d.id: d};

                  final pedidos = docs
                      .map((d) => controller.parsePedidoRow(d))
                      .where((p) => p.estado.toLowerCase() == 'entregado')
                      .toList();

                  final filtered = controller.filterPedidos(
                    pedidos: pedidos,
                    query: _q,
                    estado: 'Todos',
                  );

                  if (filtered.isEmpty) {
                    return _EmptyEntregados(query: _q);
                  }

                  final totalPages =
                      (filtered.length / _pageSize).ceil().clamp(1, 99999);
                  final page = _currentPage.clamp(0, totalPages - 1);
                  final pageFiltered =
                      filtered.skip(page * _pageSize).take(_pageSize).toList();
                  final sections = controller.groupByDepartamento(pageFiltered);

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          itemCount: sections.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      'Resultados',
                                      style: TextStyle(
                                        color: ink.withValues(alpha: 0.55),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CountPill(count: filtered.length),
                                    const Spacer(),
                                    if (!compact)
                                      const HintPill(
                                          text:
                                              'Toca un pedido para ver detalle'),
                                  ],
                                ),
                              );
                            }

                            final s = sections[i - 1];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _DeptoBlockEntregado(
                                title: s.departamento,
                                count: s.pedidos.length,
                                children: List.generate(s.pedidos.length, (idx) {
                                  final p = s.pedidos[idx];
                                  final delay =
                                      math.min(420, (idx + i) * 18);

                                  return StaggerIn(
                                    delayMs: delay,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: idx == s.pedidos.length - 1
                                            ? 0
                                            : 10,
                                      ),
                                      child: PedidoCard(
                                        pedido: p,
                                        onTap: () async {
                                          final doc = idToDoc[p.id];
                                          if (doc == null) return;
                                          await showPedidoDetalleDialog(
                                              context, doc.id);
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                      ),
                      AdminPaginationBar(
                        currentPage: page,
                        totalItems: filtered.length,
                        pageSize: _pageSize,
                        onPrev: page > 0
                            ? () => setState(() => _currentPage = page - 1)
                            : null,
                        onNext: (page + 1) * _pageSize < filtered.length
                            ? () => setState(() => _currentPage = page + 1)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= HEADER ================= */

class _EntregadosHeader extends StatelessWidget {
  const _EntregadosHeader({
    required this.compact,
    required this.bgCtrl,
    required this.searchCtrl,
  });

  final bool compact;
  final AnimationController bgCtrl;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final t = bgCtrl.value;

        final left = Color.lerp(
          const Color(0xFF2E7D32).withValues(alpha: 0.95),
          const Color(0xFF43A047).withValues(alpha: 0.90),
          0.10 + 0.25 * t,
        )!;
        final mid = Color.lerp(
          const Color(0xFF2E7D32).withValues(alpha: 0.95),
          const Color(0xFF66BB6A).withValues(alpha: 0.90),
          0.45 + 0.20 * t,
        )!;
        final right = Color.lerp(
          const Color(0xFF388E3C).withValues(alpha: 0.95),
          const Color(0xFF43A047).withValues(alpha: 0.90),
          0.80 - 0.20 * t,
        )!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [left, mid, right],
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
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.done_all_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedidos Entregados',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Historial de pedidos completados',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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
                      Icon(Icons.search_rounded,
                          color: ink.withValues(alpha: 0.45)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: compact
                                ? 'Buscar por código, dirección…'
                                : 'Buscar por código, dirección o depto…',
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
                                ? const SizedBox(
                                    width: 10, key: ValueKey('empty'))
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
      },
    );
  }
}

/* ================= BLOQUE POR DEPTO ================= */

class _DeptoBlockEntregado extends StatelessWidget {
  const _DeptoBlockEntregado({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.map_rounded,
                    color: Color(0xFF2E7D32), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Palette.fieldBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ink.withValues(alpha: 0.06)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/* ================= EMPTY STATE ================= */

class _EmptyEntregados extends StatelessWidget {
  const _EmptyEntregados({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.done_all_rounded,
              size: 56,
              color: ink.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'Sin resultados para "$query"'
                  : 'Aún no hay pedidos entregados',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink.withValues(alpha: 0.45),
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
