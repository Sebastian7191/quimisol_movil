import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/pedidos_controller.dart';
import 'detalle_pedido.dart';
import 'widgets/micro_widgets.dart';
import 'widgets/stagger_in.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> with TickerProviderStateMixin {
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

  Future<void> _openEstadoSheet() async {
    final ink = Palette.ink;

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

    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: Palette.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Palette.button.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Palette.button.withValues(alpha: 0.28)),
                      ),
                      child: Icon(Icons.filter_list_rounded, color: ink),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Filtrar por estado',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, color: ink.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...items.map((e) {
                  final selected = e == _estado;
                  return InkWell(
                    onTap: () => Navigator.pop(context, e),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Palette.button.withValues(alpha: 0.14)
                            : Palette.fieldBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? Palette.button.withValues(alpha: 0.45)
                              : Palette.ink.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: selected
                                ? Palette.primary
                                : ink.withValues(alpha: 0.35),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              labelFor(e),
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (res == null) return;
    setState(() => _estado = res);
  }

  String _estadoLabel(String v) {
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

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 520; // móvil real

    return Scaffold(
      backgroundColor: Palette.card,
      floatingActionButton: compact
          ? _FilterPillFab(
              label: _estadoLabel(_estado),
              onTap: _openEstadoSheet,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            _PedidosHeader(
              compact: compact,
              bgCtrl: _bgCtrl,
              searchCtrl: _searchCtrl,
              estado: _estado,
              onEstado: (v) => setState(() => _estado = v),
              onOpenEstadoSheet: _openEstadoSheet,
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
                    return const LoadingFancy(text: 'Cargando pedidos…');
                  }

                  final docs = snap.data?.docs ?? [];
                  final idToDoc = {for (final d in docs) d.id: d};

                  final pedidos = docs.map((d) => controller.parsePedidoRow(d)).toList();

                  final filtered = controller.filterPedidos(
                    pedidos: pedidos,
                    query: _q,
                    estado: _estado,
                  );

                  if (filtered.isEmpty) {
                    return EmptyState(query: _q, estado: _estado);
                  }

                  final sections = controller.groupByDepartamento(filtered);

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                                const HintPill(text: 'Toca un pedido para ver detalle'),
                            ],
                          ),
                        );
                      }

                      final s = sections[i - 1];
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

/* ================= FAB FILTRO (UN SOLO FONDO + BORDE) ================= */

class _FilterPillFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterPillFab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Palette.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.button.withValues(alpha: 0.95), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, color: Palette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_up_rounded, color: ink.withValues(alpha: 0.65)),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= HEADER ================= */

class _PedidosHeader extends StatelessWidget {
  const _PedidosHeader({
    required this.compact,
    required this.bgCtrl,
    required this.searchCtrl,
    required this.estado,
    required this.onEstado,
    required this.onOpenEstadoSheet,
  });

  final bool compact;
  final AnimationController bgCtrl;
  final TextEditingController searchCtrl;
  final String estado;
  final ValueChanged<String> onEstado;
  final VoidCallback onOpenEstadoSheet;

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
          0.10 + 0.25 * t,
        )!;
        final mid = Color.lerp(
          Palette.primary.withValues(alpha: 0.95),
          Palette.secondary.withValues(alpha: 0.90),
          0.45 + 0.20 * t,
        )!;
        final right = Color.lerp(
          Palette.primary.withValues(alpha: 0.95),
          Palette.secondary.withValues(alpha: 0.90),
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

                    // ✅ En móvil: mejor botón (abre bottom sheet)
                    if (compact)
                      InkWell(
                        onTap: onOpenEstadoSheet,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      )
                    else
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
          onChanged: (v) => onChanged(v ?? 'Todos'),
          selectedItemBuilder: (_) => items.map((e) => Center(child: Text(labelFor(e)))).toList(),
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
                  border: Border.all(color: Palette.primary.withValues(alpha: 0.10)),
                ),
                child: const Icon(Icons.map_rounded, color: Palette.primary, size: 18),
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
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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