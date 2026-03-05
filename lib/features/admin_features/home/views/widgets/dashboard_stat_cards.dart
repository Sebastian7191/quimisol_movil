import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../data/dashboard_models.dart';

class DashboardStatCards extends StatelessWidget {
  const DashboardStatCards({super.key, required this.width, required this.stats});
  final double width;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final isWide = width >= 1100;
    final isMid = width >= 800 && width < 1100;
    final cols = isWide ? 4 : (isMid ? 2 : 1);

    final cards = <_StatCardData>[
      _StatCardData('Pedidos', 'Total', Icons.receipt_long_rounded, stats.pedidosTotal, Palette.primary),
      _StatCardData('Pendientes', 'Por atender', Icons.timelapse_rounded, stats.pedidosPendientes, Palette.statsWarning),
      _StatCardData('En camino', 'En reparto', Icons.local_shipping_rounded, stats.pedidosEnCamino, Palette.secondary),
      _StatCardData('Entregados', 'Completados', Icons.check_circle_rounded, stats.pedidosEntregados, Palette.statsSuccess),

      _StatCardData('Ventas', 'Suma total (Bs)', Icons.payments_rounded, stats.ventasTotal.round(), Palette.primary),
      _StatCardData('Envío', 'Costo total (Bs)', Icons.delivery_dining_rounded, stats.costoEnvioTotal.round(), Palette.secondary),
      _StatCardData('Productos', 'Catálogo', Icons.inventory_2_rounded, stats.productosTotal, Palette.secondary),
      _StatCardData('Stock bajo', '≤ 5', Icons.warning_amber_rounded, stats.productosStockBajo, Palette.statsDanger),

      _StatCardData('Usuarios', 'Registrados', Icons.people_alt_rounded, stats.usuariosTotal, Palette.statsNeutral),
      _StatCardData('Repartidores', 'Registrados', Icons.badge_rounded, stats.repartidoresTotal, Palette.primary),
      _StatCardData('Banners', 'Total', Icons.campaign_rounded, stats.bannersTotal, Palette.secondary),
      _StatCardData('Banners activos', 'ACTIVO', Icons.verified_rounded, stats.bannersActivos, Palette.statsSuccess),
    ];

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: cols == 1 ? 3.0 : 2.6,
      children: cards.map((d) => _StatCard(d: d)).toList(),
    );
  }
}

class _StatCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final Color accent;
  _StatCardData(this.title, this.subtitle, this.icon, this.value, this.accent);
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.d});
  final _StatCardData d;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: d.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: d.accent.withValues(alpha: 0.28)),
            ),
            child: Icon(d.icon, color: d.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Palette.ink,
                    )),
                const SizedBox(height: 4),
                Text(
                  d.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Palette.ink.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            d.value.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}
