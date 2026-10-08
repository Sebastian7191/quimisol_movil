import 'dart:math' as math;

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

    Widget legend({required bool dense}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: top.asMap().entries.map((kv) {
          final i = kv.key;
          final e = kv.value;
          return Padding(
            padding: EdgeInsets.only(bottom: dense ? 6 : 8),
            child: Row(
              mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
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
                if (dense)
                  Text(
                    e.key,
                    style: TextStyle(color: Palette.ink.withValues(alpha: 0.8), fontWeight: FontWeight.w800, fontSize: 12),
                  )
                else
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
      );
    }

    // ✅ El radio se calcula a partir del tamaño realmente disponible para
    // que el círculo nunca desborde la tarjeta (antes usaba valores fijos
    // que en pantallas angostas sobresalían del contenedor).
    Widget pie(double size) {
      return SizedBox(
        width: size,
        height: size,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: size * 0.16,
            sections: List.generate(top.length, (i) {
              final e = top[i];
              final pct = total == 0 ? 0 : (e.value * 100 / total);
              return PieChartSectionData(
                value: e.value.toDouble(),
                title: '${pct.toStringAsFixed(0)}%',
                radius: size * 0.34,
                color: colors[i % colors.length].withValues(alpha: 0.85),
                titleStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
              );
            }),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        const legendWidth = 160.0;
        const gap = 14.0;
        final sideBySide = c.maxWidth >= legendWidth + gap + 160;

        if (sideBySide) {
          final chartSize = math.min(200.0, c.maxWidth - legendWidth - gap);
          return SizedBox(
            height: 240,
            child: Row(
              children: [
                Expanded(child: Center(child: pie(chartSize))),
                const SizedBox(width: gap),
                SizedBox(width: legendWidth, child: legend(dense: false)),
              ],
            ),
          );
        }

        final chartSize = math.min(200.0, c.maxWidth);
        return Column(
          children: [
            Center(child: pie(chartSize)),
            const SizedBox(height: 16),
            legend(dense: true),
          ],
        );
      },
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
