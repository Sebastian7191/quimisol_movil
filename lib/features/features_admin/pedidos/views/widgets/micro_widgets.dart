import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../../data/pedido_row.dart';

class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count});
  final int count;

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
        '$count',
        style: TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
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
          color: ink.withValues(alpha: 0.55),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final st = normalizeEstado(estado);
    final c = _statusColor(st);
    final label = _label(st);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Palette.ink.withValues(alpha: 0.9),
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
        ),
      ),
    );
  }

  String _label(String s) {
    switch (normalizeEstado(s)) {
      case kEstadoEntregado:
        return 'Entregado';
      case kEstadoCancelado:
        return 'Cancelado';
      case kEstadoEnCamino:
        return 'En camino';
      case kEstadoAceptado:
        return 'Aceptado';
      case kEstadoPendiente:
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String s) {
    switch (normalizeEstado(s)) {
      case kEstadoEntregado:
        return Palette.statsSuccess;
      case kEstadoCancelado:
        return Palette.statsDanger;
      case kEstadoEnCamino:
        return Palette.statsWarning;
      case kEstadoAceptado:
        return Palette.secondary;
      case kEstadoPendiente:
      default:
        return Palette.primary;
    }
  }
}

Widget miniPill(IconData icon, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Palette.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Palette.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.72),
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );
}

Color statusColor(String s) {
  switch (normalizeEstado(s)) {
    case kEstadoEntregado:
      return Palette.statsSuccess;
    case kEstadoCancelado:
      return Palette.statsDanger;
    case kEstadoEnCamino:
      return Palette.statsWarning;
    case kEstadoAceptado:
      return Palette.secondary;
    case kEstadoPendiente:
    default:
      return Palette.primary;
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
            height: 34,
            width: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: ink.withValues(alpha: 0.6),
              fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 44,
                color: ink.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 10),
              Text(
                'Sin resultados',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Estado: $estado${query.isEmpty ? '' : ' • "$query"'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PedidoCard extends StatelessWidget {
  const PedidoCard({super.key, required this.pedido, required this.onTap});

  final PedidoRow pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final ink = Palette.ink;

    final codigo = p.codigo.isEmpty ? '—' : p.codigo;
    final estado = p.estado;

    final direccion = p.direccion;
    final depto = p.departamento;
    final conteo = p.conteoItems;

    //final totalFinal = p.totalFinal;

    final fecha = p.fechaLabel;
    final c = statusColor(estado);

    return Material(
      color: Palette.fieldBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 64,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$codigo',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        EstadoChip(estado: estado),
                        const Spacer(),
                        Text(
                          fecha.isEmpty ? '—' : fecha,
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
                      direccion.isEmpty ? '—' : direccion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.8,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        miniPill(
                          Icons.map_rounded,
                          depto.isEmpty ? '—' : depto,
                        ),
                        miniPill(Icons.shopping_bag_rounded, 'Items: $conteo'),
                        miniPill(Icons.payments_rounded, p.totalLabel),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: ink.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
