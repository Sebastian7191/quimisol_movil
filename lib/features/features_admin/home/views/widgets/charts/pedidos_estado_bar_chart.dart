import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../data/dashboard_models.dart';

class PedidosEstadoBarChart extends StatelessWidget {
  const PedidosEstadoBarChart({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final keys = [kEstadoPendiente, kEstadoAceptado, kEstadoEnCamino, kEstadoEntregado, kEstadoCancelado];
    final labels = ['pendiente', 'aceptado', 'en_camino', 'entregado', 'cancelado'];
    final values = keys.map((k) => stats.pedidosPorEstado[k] ?? 0).toList();

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
                reservedSize: 38,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: TextStyle(color: Palette.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w700, fontSize: 13),
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
                      t,
                      style: TextStyle(color: Palette.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(keys.length, (i) {
            final v = values[i].toDouble();
            final color = switch (keys[i]) {
              kEstadoPendiente => Palette.statsWarning,
              kEstadoAceptado => Palette.statsNeutral,
              kEstadoEnCamino => Palette.secondary,
              kEstadoEntregado => Palette.statsSuccess,
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
