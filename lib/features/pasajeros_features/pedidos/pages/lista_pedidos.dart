// lib/features/pedidos/mis_pedidos_page.dart
//
// ✅ Fondo blanco
// ✅ Cards rosadas
// ✅ Textos MORADOS (Palette.primary)
// ✅ Status: Entregado=verde (Palette.statsSuccess) | Cancelado=rojo (Palette.statsDanger) | En camino=naranja (Palette.statsWarning)

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class MisPedidosPage extends StatefulWidget {
  const MisPedidosPage({super.key});

  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage> {
  int _tab = 0;

  final List<_PedidoModel> _pedidos = [
    _PedidoModel(
      id: 'ORD-3920',
      total: 120.50,
      dateText: '15 Oct, 2023 • 10:30 AM',
      itemsCount: 3,
      status: _PedidoStatus.enCamino,
      thumbUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=300&q=60',
    ),
    _PedidoModel(
      id: 'ORD-4400',
      total: 45.00,
      dateText: '12 Oct, 2023 • 02:15 PM',
      itemsCount: 1,
      status: _PedidoStatus.entregado,
      thumbUrl:
          'https://images.unsplash.com/photo-1518441902117-f0a96b4d29f5?auto=format&fit=crop&w=300&q=60',
    ),
    _PedidoModel(
      id: 'ORD-4392',
      total: 32.50,
      dateText: '28 Sep, 2023 • 09:45 AM',
      itemsCount: 2,
      status: _PedidoStatus.entregado,
      thumbUrl:
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=300&q=60',
    ),
    _PedidoModel(
      id: 'ORD-4100',
      total: 65.00,
      oldTotal: 85.00,
      dateText: '20 Sep, 2023 • 06:10 PM',
      itemsCount: 1,
      status: _PedidoStatus.cancelado,
      thumbUrl:
          'https://images.unsplash.com/photo-1511499767150-a48a237f0083?auto=format&fit=crop&w=300&q=60',
    ),
  ];

  List<_PedidoModel> get _filtered {
    if (_tab == 0) return _pedidos;
    if (_tab == 1) {
      return _pedidos.where((p) => p.status == _PedidoStatus.enCamino).toList();
    }
    if (_tab == 2) {
      return _pedidos.where((p) => p.status == _PedidoStatus.entregado).toList();
    }
    return _pedidos.where((p) => p.status == _PedidoStatus.cancelado).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button; // rosa
    final purpleText = Palette.primary; // morado textos
    final ink = Palette.ink;

    final bg = Palette.fieldBg; // blanco

    // Cards rosadas
    final cardA = Palette.button.withOpacity(0.92);
    final cardB = Palette.gradientEnd.withOpacity(0.90);

    final chipBg = Palette.button.withOpacity(0.10);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: purpleText),
                  ),
                  const Spacer(),
                  Text(
                    'Mis Pedidos',
                    style: TextStyle(
                      color: purpleText,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ink.withOpacity(0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(Icons.search_rounded,
                          color: purpleText.withOpacity(0.90), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ChipTab(
                    text: 'Todos',
                    active: _tab == 0,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'En Proceso',
                    active: _tab == 1,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'Entregado',
                    active: _tab == 2,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 2),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'Cancelado',
                    active: _tab == 3,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lista
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PedidoCard(
                      pedido: p,
                      cardA: cardA,
                      cardB: cardB,
                      purpleText: purpleText,
                      onTap: () {},
                    ),
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

/* ---------------- UI ---------------- */

class _ChipTab extends StatelessWidget {
  const _ChipTab({
    required this.text,
    required this.active,
    required this.primary,
    required this.bg,
    required this.textColor,
    required this.onTap,
  });

  final String text;
  final bool active;
  final Color primary;
  final Color bg;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? primary : bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? primary : textColor.withOpacity(0.12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Palette.white : textColor.withOpacity(0.92),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _PedidoCard extends StatelessWidget {
  const _PedidoCard({
    required this.pedido,
    required this.cardA,
    required this.cardB,
    required this.purpleText,
    required this.onTap,
  });

  final _PedidoModel pedido;
  final Color cardA;
  final Color cardB;
  final Color purpleText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(pedido.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardA, cardB],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                // Thumb
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(pedido.thumbUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),

                // Info (texto morado)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${pedido.id}',
                        style: TextStyle(
                          color: purpleText,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pedido.dateText,
                        style: TextStyle(
                          color: purpleText.withOpacity(0.75),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Total + items (texto morado)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${pedido.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: purpleText,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        if (pedido.oldTotal != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '\$${pedido.oldTotal!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: purpleText.withOpacity(0.65),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pedido.itemsCount} articulo${pedido.itemsCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: purpleText.withOpacity(0.75),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(color: Colors.white.withOpacity(0.35), height: 1),
            const SizedBox(height: 10),

            // Status + action
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: status.bg, // ✅ verde/rojo/naranja desde Palette
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(status.icon, size: 16, color: Palette.white),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  status.actionText,
                  style: TextStyle(
                    color: purpleText.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: purpleText.withOpacity(0.85)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Status Meta ---------------- */

class _StatusMeta {
  final String label;
  final String actionText;
  final IconData icon;
  final Color bg;

  _StatusMeta({
    required this.label,
    required this.actionText,
    required this.icon,
    required this.bg,
  });
}

_StatusMeta _statusMeta(_PedidoStatus status) {
  switch (status) {
    case _PedidoStatus.enCamino:
      return _StatusMeta(
        label: 'En Camino',
        actionText: 'Ver seguimiento',
        icon: Icons.local_shipping_outlined,
        bg: Palette.statsWarning, // ✅ naranja
      );
    case _PedidoStatus.entregado:
      return _StatusMeta(
        label: 'Entregado',
        actionText: 'Ver detalles',
        icon: Icons.check_circle_outline_rounded,
        bg: Palette.statsSuccess, // ✅ verde
      );
    case _PedidoStatus.cancelado:
      return _StatusMeta(
        label: 'Cancelado',
        actionText: 'Ver resumen',
        icon: Icons.cancel_outlined,
        bg: Palette.statsDanger, // ✅ rojo
      );
  }
}

/* ---------------- Model ---------------- */

enum _PedidoStatus { enCamino, entregado, cancelado }

class _PedidoModel {
  final String id;
  final double total;
  final double? oldTotal;
  final String dateText;
  final int itemsCount;
  final _PedidoStatus status;
  final String thumbUrl;

  const _PedidoModel({
    required this.id,
    required this.total,
    this.oldTotal,
    required this.dateText,
    required this.itemsCount,
    required this.status,
    required this.thumbUrl,
  });
}
