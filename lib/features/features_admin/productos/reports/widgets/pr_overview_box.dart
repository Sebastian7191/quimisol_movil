import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class PredictiveOverviewBox extends StatelessWidget {
  const PredictiveOverviewBox({required this.overview});
  final Map<String, dynamic> overview;

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalProducts = _asInt(overview['productsAnalyzed']);
    final atRisk = _asInt(overview['productsAtRiskCount']);
    final rising = _asInt(overview['risingProductsCount']);
    final falling = _asInt(overview['fallingProductsCount']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          StatTile(
            title: 'Productos',
            value: totalProducts == 0 ? '—' : '$totalProducts',
            icon: Icons.inventory_2_outlined,
            color: Palette.primary,
          ),
          StatTile(
            title: 'Riesgo de quiebre',
            value: atRisk == 0 ? '—' : '$atRisk',
            icon: Icons.warning_amber_rounded,
            color: Palette.statsDanger,
          ),
          StatTile(
            title: 'Tendencia al alza',
            value: rising == 0 ? '—' : '$rising',
            icon: Icons.trending_up_rounded,
            color: Palette.statsSuccess,
          ),
          StatTile(
            title: 'Tendencia a la baja',
            value: falling == 0 ? '—' : '$falling',
            icon: Icons.trending_down_rounded,
            color: Palette.statsWarning,
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: Palette.ink.withValues(alpha: 0.70),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
