import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../data/dashboard_models.dart';

class PedidosDepartamentoPie extends StatelessWidget {
  const PedidosDepartamentoPie({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = stats.pedidosPorDepartamento.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _empty('Sin datos de departamento');
    }

    final top = entries.take(6).toList(); // top 6
    final total = top.fold<int>(0, (a, b) => a + b.value);

    final colors = <Color>[
      Palette.primary,
      Palette.secondary,
      Palette.statsSuccess,
      Palette.statsWarning,
      Palette.statsDanger,
      Palette.statsNeutral,
    ];

    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: List.generate(top.length, (i) {
                  final e = top[i];
                  final pct = total == 0 ? 0 : (e.value * 100 / total);
                  return PieChartSectionData(
                    value: e.value.toDouble(),
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 80,
                    color: colors[i % colors.length].withValues(alpha: 0.85),
                    titleStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: top.asMap().entries.map((kv) {
                final i = kv.key;
                final e = kv.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length].withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Palette.ink.withValues(alpha: 0.8), fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.value.toString(),
                        style: const TextStyle(color: Palette.ink, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String t) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w800, color: Palette.ink.withValues(alpha: 0.7)),
      ),
    );
  }
}
