import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../data/dashboard_models.dart';

class PedidosLineChart extends StatelessWidget {
  const PedidosLineChart({super.key, required this.stats, required this.range});
  final DashboardStats stats;
  final DashboardRange range;

  @override
  Widget build(BuildContext context) {
    // eje según rango
    DateTime start;
    int days;

    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);

    switch (range) {
      case DashboardRange.today:
        start = today0;
        days = 1;
        break;
      case DashboardRange.last7:
        start = today0.subtract(const Duration(days: 6));
        days = 7;
        break;
      case DashboardRange.last30:
        start = today0.subtract(const Duration(days: 29));
        days = 30;
        break;
      case DashboardRange.all:
        // fallback: 30 días
        start = today0.subtract(const Duration(days: 29));
        days = 30;
        break;
    }

    final axis = buildDayAxis(start, days);
    final spots = <FlSpot>[];

    for (var i = 0; i < axis.length; i++) {
      final d = axis[i];
      final v = stats.pedidosPorDia[d] ?? 0;
      spots.add(FlSpot(i.toDouble(), v.toDouble()));
    }

    final maxY = spots.isEmpty ? 1.0 : spots.map((e) => e.y).fold(1.0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY + 1,
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
                interval: days <= 7 ? 1 : 5,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= axis.length) return const SizedBox.shrink();
                  final d = axis[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: TextStyle(color: Palette.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: Palette.primary,
              dotData: FlDotData(show: days <= 7),
              belowBarData: BarAreaData(
                show: true,
                color: Palette.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
