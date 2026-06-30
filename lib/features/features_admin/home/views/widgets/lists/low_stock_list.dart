import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../data/dashboard_models.dart';

class LowStockList extends StatelessWidget {
  const LowStockList({super.key, required this.items});
  final List<ProductoMini> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _empty('No hay productos con stock bajo 🎉');
    }

    return Column(
      children: items.map((p) {
        final danger = p.stock <= 0;
        final warn = p.stock > 0 && p.stock <= 5;
        final color = danger ? Palette.statsDanger : (warn ? Palette.statsWarning : Palette.secondary);

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
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Palette.ink)),
                    if (p.almacenNombre.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.almacenNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.ink.withValues(alpha: 0.65)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text('Stock: ${p.stock}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
              ),
            ],
          ),
        );
      }).toList(),
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
