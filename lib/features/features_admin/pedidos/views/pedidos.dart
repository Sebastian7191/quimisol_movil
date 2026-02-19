import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/pedidos/views/detalle_pedido.dart';

import '../controllers/pedidos_controller.dart';
import 'widgets/micro_widgets.dart';
import 'widgets/stagger_in.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _q = '';
  String _estado = 'Todos';

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
      setState(() => _q = v);
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pedidosStream() {
    return FirebaseFirestore.instance
        .collection('pedidos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  bool matches(Map<String, dynamic> p) {
    final estado = normalizeEstado(p['estado']);

    if (_estado != 'Todos' && estado != _estado) return false;

    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();

    final codigo = (p['codigo'] ?? '').toString().toLowerCase();
    final direccion = (p['direccion'] ?? '').toString().toLowerCase();
    final uid = (p['uid'] ?? '').toString().toLowerCase();
    final depto = (p['departamento'] ?? '').toString().toLowerCase();

    return codigo.contains(q) || direccion.contains(q) || uid.contains(q) || depto.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: Column(
        children: [
          _PedidosHeader(
            bgCtrl: _bgCtrl,
            searchCtrl: _searchCtrl,
            estado: _estado,
            onEstado: (v) => setState(() => _estado = v),
          ),
          Expanded(
            child: StreamBuilder(
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
                  return const LoadingFancy(text: 'Cargando pedidos…');
                }

                final docs = snap.data?.docs ?? [];
                final idToDoc = {for (final d in docs) d.id: d};
                final pedidos = docs
                    .map((d) => controller.parsePedidoRow(d))
                    .toList();

                final filtered = controller.filterPedidos(
                  pedidos: pedidos,
                  query: _q,
                  estado: _estado,
                );

                if (filtered.isEmpty) {
                  return EmptyState(query: _q, estado: _estado);
                }

                final sections = controller.groupByDepartamento(filtered);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                          const HintPill(
                            text: 'Toca un pedido para ver detalle',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: sections.length,
                        itemBuilder: (_, i) {
                          final s = sections[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _DeptoBlock(
                              title: s.departamento,
                              count: s.pedidos.length,
                              children: List.generate(s.pedidos.length, (idx) {
                                final p = s.pedidos[idx];
                                final delay = math.min(420, (idx + i) * 18);
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

                                        //cambio aquí
                                        await showPedidoDetalleDialog(
                                          context,
                                          doc.id,
                                        );
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= HEADER ================= */
class _PedidosHeader extends StatelessWidget {
  const _PedidosHeader({
    required this.bgCtrl,
    required this.searchCtrl,
    required this.estado,
    required this.onEstado,
  });

  final AnimationController bgCtrl;
  final TextEditingController searchCtrl;
  final String estado;
  final ValueChanged<String> onEstado;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final t = bgCtrl.value;

        final left = Color.lerp(
        Palette.primary.withValues(alpha: 0.95),
        Palette.secondary.withValues(alpha: 0.90),
        0.10 + 0.25 * t)!;

        final mid = Color.lerp(
        Palette.primary.withValues(alpha: 0.95),
        Palette.secondary.withValues(alpha: 0.90),
        0.45 + 0.20 * t)!;

        final right = Color.lerp(
        Palette.primary.withValues(alpha: 0.95),
        Palette.secondary.withValues(alpha: 0.90),
        0.80 - 0.20 * t)!;

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
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedidos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Gestiona pedidos por departamento',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _EstadoFilterMini(value: estado, onChanged: onEstado),
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
                      Icon(
                        Icons.search_rounded,
                        color: ink.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por código, dirección, uid o depto…',
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
                                    width: 10,
                                    key: ValueKey('empty'),
                                  )
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

class _EstadoFilterMini extends StatelessWidget {
  const _EstadoFilterMini({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

  // Acá creo esta fallando los filtros pero no se porque xd
    const items = <String>[
      'Todos',
      kEstadoPendiente,
      kEstadoAceptado,
      kEstadoEnCamino,
      kEstadoEntregado,
      kEstadoCancelado,
    ];

    String labelFor(String v) {
      switch (v) {
        case kEstadoPendiente:
          return 'Pendiente';
        case kEstadoAceptado:
          return 'Aceptado';
        case kEstadoEnCamino:
          return 'En camino';
        case kEstadoEntregado:
          return 'Entregado';
        case kEstadoCancelado:
          return 'Cancelado';
        default:
          return 'Todos';
      }
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: Palette.white,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
          onChanged: (v) => onChanged(v ?? 'Todos'),
          selectedItemBuilder: (_) =>
              items.map((e) => Center(child: Text(labelFor(e)))).toList(),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    labelFor(e),
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

/* ================= SECCIONES POR DEPTO ================= */

class _DeptoBlock extends StatelessWidget {
  const _DeptoBlock({
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
                  color: Palette.button.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Palette.primary.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Palette.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                    fontSize: 12,
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