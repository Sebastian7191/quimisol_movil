import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../data/dashboard_models.dart';

class PedidosEstadoBarChart extends StatelessWidget {
  const PedidosEstadoBarChart({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final labels = ['pendiente', 'aceptado', 'en camino', 'entregado', 'cancelado'];
    final values = labels.map((k) => stats.pedidosPorEstado[k] ?? 0).toList();

    final maxY = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: (maxY + 1).toDouble(),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true, border: Border.all(color: Palette.primary.withValues(alpha: 0.12))),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: TextStyle(color: Palette.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  final t = labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      t == 'en camino' ? 'en_camino' : t,
                      style: TextStyle(color: Palette.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            final v = values[i].toDouble();
            final color = switch (labels[i]) {
              'pendiente' => Palette.statsWarning,
              'aceptado' => Palette.statsNeutral,
              'en camino' => Palette.secondary,
              'entregado' => Palette.statsSuccess,
              _ => Palette.statsDanger,
            };

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: v,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  color: color,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
