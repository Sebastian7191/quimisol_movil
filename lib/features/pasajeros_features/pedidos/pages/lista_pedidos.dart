// lib/features/pedidos/mis_pedidos_page.dart
//
// ✅ Funcional con Firestore (usuarios/{uid}/pedidos) realtime (ÍNDICE del usuario)
// ✅ Fondo blanco
// ✅ Cards rosadas
// ✅ Textos MORADOS (Palette.primary)
// ✅ Status: Entregado=verde (Palette.statsSuccess) | Cancelado=rojo (Palette.statsDanger) | En camino/pendiente=naranja (Palette.statsWarning)
// ✅ Lista: NO muestra imagen de producto (solo icono rosado de pedido con fondo blanco)
// ✅ Tap: abre detalle_pedido.dart (DetallePedidoPage)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/pages/detalle_producto.dart';

class MisPedidosPage extends StatefulWidget {
  const MisPedidosPage({super.key});

  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage> {
  int _tab = 0;

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// ✅ Índice: SOLO pedidos del usuario logueado
  CollectionReference<Map<String, dynamic>> get _pedidosRef =>
      _fire.collection('usuarios').doc(_uid).collection('pedidos');

  String _norm(String s) => s.trim().toLowerCase();

  _PedidoStatus _mapStatus(String raw) {
    final s = _norm(raw);

    if (s == 'pendiente' || s == 'en proceso' || s == 'proceso') {
      return _PedidoStatus.enProceso;
    }

    if (s == 'en_camino' || s == 'en camino' || s == 'encamino') {
      return _PedidoStatus.enCamino;
    }

    if (s == 'entregado' || s == 'entregada') return _PedidoStatus.entregado;
    if (s == 'cancelado' || s == 'cancelada') return _PedidoStatus.cancelado;

    return _PedidoStatus.enProceso;
  }

  bool _passesTab(_PedidoStatus st) {
    if (_tab == 0) return true;
    if (_tab == 1) return st == _PedidoStatus.enProceso || st == _PedidoStatus.enCamino;
    if (_tab == 2) return st == _PedidoStatus.entregado;
    return st == _PedidoStatus.cancelado;
  }

  String _formatDate(dynamic createdAt) {
    try {
      if (createdAt is Timestamp) {
        final d = createdAt.toDate();
        final dd = d.day.toString().padLeft(2, '0');
        final mm = d.month.toString().padLeft(2, '0');
        final yyyy = d.year.toString();
        final hh = d.hour.toString().padLeft(2, '0');
        final mi = d.minute.toString().padLeft(2, '0');
        return '$dd/$mm/$yyyy • $hh:$mi';
      }
    } catch (_) {}
    return '—';
  }

  int _itemsCount(dynamic items, dynamic itemsCount) {
    if (itemsCount is num) return itemsCount.toInt();
    if (items is List) return items.length;
    return 0;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button; // rosa
    final purpleText = Palette.primary; // morado
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
                      child: Icon(
                        Icons.search_rounded,
                        color: purpleText.withOpacity(0.90),
                        size: 20,
                      ),
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

            Expanded(
              child: _uid.isEmpty
                  ? Center(
                      child: Text(
                        'Inicia sesión para ver tus pedidos.',
                        style: TextStyle(
                          color: purpleText.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      /// ✅ SOLO DEL USUARIO (porque es subcolección del usuario)
                      stream: _pedidosRef.orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'Ocurrió un error al cargar pedidos.\n${snap.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: purpleText.withOpacity(0.75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }

                        final docs = snap.data?.docs ?? [];

                        final all = docs.map((d) {
                          final data = d.data();

                          final rawStatus = (data['estado'] ?? 'pendiente').toString();
                          final st = _mapStatus(rawStatus);

                          /// ✅ en el índice guardamos total FINAL (si lo sigues como te dejé)
                          final total = _asDouble(data['total']);

                          final createdAt = data['createdAt'];
                          final dateText = _formatDate(createdAt);

                          final items = data['items'];
                          final itemsCount = _itemsCount(items, data['conteoItems']);

                          /// ✅ codigo, si no existe, mostramos el id
                          final code = (data['codigo'] ?? d.id).toString();

                          return _PedidoModel(
                            id: d.id, // ✅ ESTE id ES EL pedidoId real
                            code: code,
                            total: total,
                            dateText: dateText,
                            itemsCount: itemsCount,
                            status: st,
                          );
                        }).toList();

                        final filtered = all.where((p) => _passesTab(p.status)).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 54,
                                    color: purpleText.withOpacity(0.25),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No hay pedidos aquí.',
                                    style: TextStyle(
                                      color: purpleText.withOpacity(0.75),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final p = filtered[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _PedidoCard(
                                pedido: p,
                                cardA: cardA,
                                cardB: cardB,
                                purpleText: purpleText,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetallePedidoPage(
                                        pedidoId: p.id, // ✅ /pedidos/{pedidoId}
                                        pedidoCode: p.code,
                                      ),
                                    ),
                                  );
                                },
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
                // ✅ Icono de pedido: fondo blanco + icono rosado
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Palette.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: purpleText.withOpacity(0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Palette.button, // rosado
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${pedido.code}',
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${pedido.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: purpleText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: status.bg,
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
                Icon(Icons.chevron_right_rounded, color: purpleText.withOpacity(0.85)),
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
    case _PedidoStatus.enProceso:
      return _StatusMeta(
        label: 'Pendiente',
        actionText: 'Ver detalles',
        icon: Icons.timelapse_rounded,
        bg: Palette.statsWarning,
      );
    case _PedidoStatus.enCamino:
      return _StatusMeta(
        label: 'En Camino',
        actionText: 'Ver seguimiento',
        icon: Icons.local_shipping_outlined,
        bg: Palette.statsWarning,
      );
    case _PedidoStatus.entregado:
      return _StatusMeta(
        label: 'Entregado',
        actionText: 'Ver detalles',
        icon: Icons.check_circle_outline_rounded,
        bg: Palette.statsSuccess,
      );
    case _PedidoStatus.cancelado:
      return _StatusMeta(
        label: 'Cancelado',
        actionText: 'Ver resumen',
        icon: Icons.cancel_outlined,
        bg: Palette.statsDanger,
      );
  }
}

/* ---------------- Model ---------------- */

enum _PedidoStatus { enProceso, enCamino, entregado, cancelado }

class _PedidoModel {
  final String id; // ✅ pedidoId real
  final String code;
  final double total;
  final String dateText;
  final int itemsCount;
  final _PedidoStatus status;

  const _PedidoModel({
    required this.id,
    required this.code,
    required this.total,
    required this.dateText,
    required this.itemsCount,
    required this.status,
  });
}
