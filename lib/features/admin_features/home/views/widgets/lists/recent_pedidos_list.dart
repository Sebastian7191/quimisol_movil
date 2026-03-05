import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../data/dashboard_models.dart';

class RecentPedidosList extends StatelessWidget {
  const RecentPedidosList({super.key, required this.items});
  final List<PedidoMini> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _empty('Aún no hay pedidos en el rango.');
    }

    return Column(
      children: items.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
                ),
                child: Icon(Icons.shopping_bag_rounded,
                    color: Palette.primary.withValues(alpha: 0.9), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.codigo.isEmpty ? 'Pedido' : p.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Palette.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.direccion.isEmpty ? p.departamento : p.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.ink.withValues(alpha: 0.75)),
                    ),
                    if (p.repartidorNombre.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Repartidor: ${p.repartidorNombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.ink.withValues(alpha: 0.65)),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _pill(p.estado),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _pill(String estado) {
    final e = normalizeEstado(estado);
    Color c;
    String t;

    switch (e) {
      case 'pendiente':
        c = Palette.statsWarning; t = 'Pendiente'; break;
      case 'aceptado':
        c = Palette.statsNeutral; t = 'Aceptado'; break;
      case 'en camino':
        c = Palette.secondary; t = 'En camino'; break;
      case 'entregado':
        c = Palette.statsSuccess; t = 'Entregado'; break;
      case 'cancelado':
        c = Palette.statsDanger; t = 'Cancelado'; break;
      default:
        c = Palette.statsNeutral; t = estado.isEmpty ? '—' : estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
    );
  }

  Widget _empty(String t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: Palette.ink.withValues(alpha: 0.78))),
    );
  }
}
