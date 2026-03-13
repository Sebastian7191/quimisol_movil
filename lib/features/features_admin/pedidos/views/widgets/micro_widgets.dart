import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../../data/pedido_row.dart';

// ==========================
// Helpers
// ==========================

String normalizeEstado(dynamic v) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return kEstadoPendiente;

  final lower = s.toLowerCase();
  if (lower.contains('pend')) return kEstadoPendiente;
  if (lower.contains('acept')) return kEstadoAceptado;
  if (lower.contains('camino')) return kEstadoEnCamino;
  if (lower.contains('entreg')) return kEstadoEntregado;
  if (lower.contains('cancel')) return kEstadoCancelado;

  return s;
}

Color estadoColor(String s) {
  switch (normalizeEstado(s)) {
    case kEstadoEntregado:
      return Palette.statsSuccess;
    case kEstadoCancelado:
      return Palette.statsDanger;
    case kEstadoEnCamino:
      return Palette.button;
    case kEstadoAceptado:
      return Palette.secondary;
    case kEstadoPendiente:
    default:
      return Palette.primary;
  }
}

Widget statusPill(String estado) {
  final ink = Palette.ink;
  final c = estadoColor(estado);

  String labelFor(String v) {
    switch (normalizeEstado(v)) {
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
        return v.toString();
    }
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: c.withValues(alpha: 0.28)),
    ),
    child: Text(
      labelFor(estado),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: ink,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );
}

Widget miniPill(IconData icon, String text) {
  final ink = Palette.ink;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Palette.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ink.withValues(alpha: 0.06)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Palette.primary),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    ),
  );
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
}

Color statusColor(String s) => estadoColor(s);

// ==========================
// Micro widgets
// ==========================

class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
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
    );
  }
}

class HintPill extends StatelessWidget {
  const HintPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ink.withValues(alpha: 0.65),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class LoadingFancy extends StatelessWidget {
  const LoadingFancy({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: ink.withValues(alpha: 0.7),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.query, required this.estado});
  final String query;
  final String estado;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 52,
              color: ink.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              'No hay pedidos',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No se encontraron resultados para "$query"'
                  : 'Ajusta filtros o vuelve a intentar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (estado != 'Todos') ...[
              const SizedBox(height: 8),
              Text(
                'Filtro: $estado',
                style: TextStyle(
                  color: ink.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================
// PEDIDO CARD
// ==========================

class PedidoCard extends StatelessWidget {
  const PedidoCard({super.key, required this.pedido, required this.onTap});

  final PedidoRow pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final ink = Palette.ink;

    final estado = normalizeEstado(p.estado);
    final barColor = statusColor(estado);

    final code = p.codigo.trim();
    final address = p.direccion.trim();
    final depto = p.departamento.trim();
    final conteo = p.conteoItems;
    final fecha = p.fechaLabel.isNotEmpty ? p.fechaLabel : formatDateTime(p.createdAt);
    final totalLabel = p.totalLabel.isNotEmpty ? p.totalLabel : '${p.totalFinal.toStringAsFixed(2)} Bs';

    return LayoutBuilder(
      builder: (context, box) {
        final tiny = box.maxWidth < 360;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Palette.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ink.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 118,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!tiny)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  code.isEmpty ? 'Pedido' : '#$code',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              statusPill(estado),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  fecha,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: ink.withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      code.isEmpty ? 'Pedido' : '#$code',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  statusPill(estado),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fecha,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          address.isEmpty ? '-' : address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.80),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (depto.isNotEmpty) miniPill(Icons.map_rounded, depto),
                            miniPill(Icons.shopping_bag_rounded, 'Items: $conteo'),
                            miniPill(Icons.payments_rounded, totalLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: ink.withValues(alpha: 0.35),
                    size: 26,
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