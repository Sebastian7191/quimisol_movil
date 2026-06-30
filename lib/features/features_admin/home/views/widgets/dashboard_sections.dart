import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../controllers/dashboard_controller.dart';
import '../../data/dashboard_models.dart';


import 'charts/pedidos_line_chart.dart';
import 'charts/pedidos_estado_bar_chart.dart';
import 'charts/pedidos_departamento_pie.dart';
import 'lists/recent_pedidos_list.dart';
import 'lists/low_stock_list.dart';

class DashboardSections extends StatelessWidget {
  const DashboardSections({super.key, required this.width, required this.stats, required this.range});
  final double width;
  final DashboardStats stats;
  final DashboardRange range;

  @override
  Widget build(BuildContext context) {
    final stacked = width < 980;

    Widget section(String title, String subtitle, Widget child) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Palette.ink)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Palette.ink.withValues(alpha: 0.72))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
    }

    final chartsRow = stacked
        ? Column(
            children: [
              section('Pedidos por día', 'Según rango seleccionado', PedidosLineChart(stats: stats, range: range)),
              const SizedBox(height: 12),
              section('Pedidos por estado', 'Distribución', PedidosEstadoBarChart(stats: stats)),
              const SizedBox(height: 12),
              section('Pedidos por departamento', 'Participación', PedidosDepartamentoPie(stats: stats)),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: section('Pedidos por día', 'Según rango seleccionado', PedidosLineChart(stats: stats, range: range))),
              const SizedBox(width: 12),
              Expanded(child: section('Pedidos por estado', 'Distribución', PedidosEstadoBarChart(stats: stats))),
              const SizedBox(width: 12),
              Expanded(child: section('Pedidos por departamento', 'Participación', PedidosDepartamentoPie(stats: stats))),
            ],
          );

    final listsRow = stacked
        ? Column(
            children: [
              section('Pedidos recientes', 'Últimos 6', RecentPedidosList(items: stats.pedidosRecientes)),
              const SizedBox(height: 12),
              section('Stock bajo', 'Recomendado: reponer', LowStockList(items: stats.productosLowStock)),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: section('Pedidos recientes', 'Últimos 6', RecentPedidosList(items: stats.pedidosRecientes))),
              const SizedBox(width: 12),
              Expanded(child: section('Stock bajo', 'Recomendado: reponer', LowStockList(items: stats.productosLowStock))),
            ],
          );

    return Column(
      children: [
        chartsRow,
        const SizedBox(height: 14),
        listsRow,
      ],
    );
  }
}
