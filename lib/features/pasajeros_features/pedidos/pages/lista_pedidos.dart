// lib/features/pasajeros_features/pedidos/pages/lista_pedidos.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/pages/detalle_producto.dart';

class MisPedidosPage extends StatefulWidget {
  final int initialTab;

  const MisPedidosPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage> {
  late int _tab;

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _pedidosQuery => _fire
      .collection('pedidos')
      .where('uid', isEqualTo: _uid)
      .orderBy('createdAt', descending: true);

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  _PedidoStatus _mapStatus(String raw) {
    final s = _norm(raw);

    if (s == 'pendiente' || s == 'en proceso' || s == 'proceso') {
      return _PedidoStatus.pendiente;
    }

    if (s == 'aceptado' || s == 'aceptada') {
      return _PedidoStatus.aceptado;
    }

    if (s == 'en camino' ||
        s == 'encamino' ||
        s == 'en curso' ||
        s == 'encurso') {
      return _PedidoStatus.enCamino;
    }

    if (s == 'completado' ||
        s == 'completada' ||
        s == 'entregado' ||
        s == 'entregada') {
      return _PedidoStatus.completado;
    }

    if (s == 'cancelado' || s == 'cancelada') {
      return _PedidoStatus.cancelado;
    }

    return _PedidoStatus.pendiente;
  }

  bool _passesTab(_PedidoStatus st) {
    if (_tab == 0) return true;
    if (_tab == 1) return st == _PedidoStatus.pendiente;
    if (_tab == 2) return st == _PedidoStatus.aceptado;
    if (_tab == 3) return st == _PedidoStatus.enCamino;
    if (_tab == 4) return st == _PedidoStatus.completado;
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

  String _tipoPagoLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '—';
    if (s.contains('qr')) return 'QR';
    if (s.contains('efect')) return 'Efectivo';
    return raw;
  }

  String _estadoPagoLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return 'Pendiente';
    if (s.contains('rech')) return 'Rechazado';
    if (s.contains('pag')) return 'Pagado';
    if (s.contains('pend')) return 'Pendiente';
    return raw;
  }

  _PagoMeta _pagoMeta(String raw) {
    final s = raw.trim().toLowerCase();

    if (s.contains('rech')) {
      return _PagoMeta(
        label: 'Rechazado',
        icon: Icons.cancel_outlined,
        color: Palette.statsDanger,
      );
    }

    if (s.contains('pag')) {
      return _PagoMeta(
        label: 'Pagado',
        icon: Icons.check_circle_outline_rounded,
        color: Palette.statsSuccess,
      );
    }

    return _PagoMeta(
      label: 'Pendiente',
      icon: Icons.timelapse_rounded,
      color: Palette.statsWarning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button;
    final purpleText = Palette.primary;
    final bg = Palette.fieldBg;
    final chipBg = Palette.button.withOpacity(0.10);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  const SizedBox(width: 48),
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
                ],
              ),
            ),
            const SizedBox(height: 6),
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
                    text: 'Pendiente',
                    active: _tab == 1,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'Aceptado',
                    active: _tab == 2,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 2),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'En camino',
                    active: _tab == 3,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 3),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'Completado',
                    active: _tab == 4,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 4),
                  ),
                  const SizedBox(width: 10),
                  _ChipTab(
                    text: 'Cancelado',
                    active: _tab == 5,
                    primary: primary,
                    bg: chipBg,
                    textColor: purpleText,
                    onTap: () => setState(() => _tab = 5),
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
                      stream: _pedidosQuery.snapshots(),
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

                          final rawStatus =
                              (data['estado'] ?? 'pendiente').toString();
                          final st = _mapStatus(rawStatus);

                          final total = _asDouble(data['total']);
                          final createdAt = data['createdAt'];
                          final dateText = _formatDate(createdAt);

                          final items = data['items'];
                          final itemsCount =
                              _itemsCount(items, data['conteoItems']);

                          final code = (data['codigo'] ?? d.id).toString();

                          final rawTipoPago =
                              (data['tipo_pago'] ?? data['tipoPago'] ?? '')
                                  .toString();

                          final rawEstadoPago =
                              (data['estado_pago'] ?? data['estadoPago'] ?? '')
                                  .toString();

                          return _PedidoModel(
                            id: d.id,
                            code: code,
                            total: total,
                            dateText: dateText,
                            itemsCount: itemsCount,
                            status: st,
                            rawEstado: rawStatus,
                            tipoPago: _tipoPagoLabel(rawTipoPago),
                            estadoPago: _estadoPagoLabel(rawEstadoPago),
                            pagoMeta: _pagoMeta(rawEstadoPago),
                          );
                        }).toList();

                        final filtered =
                            all.where((p) => _passesTab(p.status)).toList();

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
                                purpleText: purpleText,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetallePedidoPage(
                                        pedidoId: p.id,
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
    required this.purpleText,
    required this.onTap,
  });

  final _PedidoModel pedido;
  final Color purpleText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(pedido.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: purpleText.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: status.bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: status.bg.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              status.icon,
                              color: status.bg,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pedido #${pedido.code}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: purpleText,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toca para abrir el detalle',
                                  style: TextStyle(
                                    color: purpleText.withOpacity(0.55),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoMiniCard(
                              label: 'Fecha',
                              value: pedido.dateText,
                              icon: Icons.schedule_rounded,
                              valueColor: purpleText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoMiniCard(
                              label: 'Artículos',
                              value:
                                  '${pedido.itemsCount} articulo${pedido.itemsCount == 1 ? '' : 's'}',
                              icon: Icons.inventory_2_outlined,
                              valueColor: purpleText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoMiniCard(
                              label: 'Total',
                              value: 'Bs. ${pedido.total.toStringAsFixed(2)}',
                              icon: Icons.payments_outlined,
                              valueColor: purpleText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoMiniCard(
                              label: 'Tipo de pago',
                              value: pedido.tipoPago,
                              icon: Icons.account_balance_wallet_outlined,
                              valueColor: purpleText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PagoMiniCard(
                              label: 'Estado pago',
                              value: pedido.estadoPago,
                              icon: pedido.pagoMeta.icon,
                              valueColor: pedido.pagoMeta.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: status.bg.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: status.bg.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              status.actionText,
                              style: TextStyle(
                                color: status.bg,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: status.bg,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _StatusMeta status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 14,
            color: Palette.white,
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMiniCard extends StatelessWidget {
  const _InfoMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Palette.fieldBg.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: valueColor.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: Palette.button.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Palette.button,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor.withOpacity(0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PagoMiniCard extends StatelessWidget {
  const _PagoMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: valueColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: valueColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: valueColor,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor.withOpacity(0.70),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.8,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    case _PedidoStatus.pendiente:
      return _StatusMeta(
        label: 'Pendiente',
        actionText: 'Ver detalles',
        icon: Icons.timelapse_rounded,
        bg: Palette.statsWarning,
      );

    case _PedidoStatus.aceptado:
      return _StatusMeta(
        label: 'Aceptado',
        actionText: 'Ver detalles',
        icon: Icons.verified_outlined,
        bg: Palette.statsWarning,
      );

    case _PedidoStatus.enCamino:
      return _StatusMeta(
        label: 'En camino',
        actionText: 'Ver seguimiento',
        icon: Icons.local_shipping_outlined,
        bg: Palette.statsWarning,
      );

    case _PedidoStatus.completado:
      return _StatusMeta(
        label: 'Completado',
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

enum _PedidoStatus { pendiente, aceptado, enCamino, completado, cancelado }

class _PedidoModel {
  final String id;
  final String code;
  final double total;
  final String dateText;
  final int itemsCount;
  final _PedidoStatus status;
  final String rawEstado;
  final String tipoPago;
  final String estadoPago;
  final _PagoMeta pagoMeta;

  const _PedidoModel({
    required this.id,
    required this.code,
    required this.total,
    required this.dateText,
    required this.itemsCount,
    required this.status,
    required this.rawEstado,
    required this.tipoPago,
    required this.estadoPago,
    required this.pagoMeta,
  });
}

class _PagoMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _PagoMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
}