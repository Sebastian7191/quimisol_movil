import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../data/dashboard_models.dart';
import 'dashboard_detail_dialog.dart';

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
      _StatCardData(
        'Pedidos', 'Total',
        Icons.receipt_long_rounded,
        stats.pedidosTotal,
        Palette.primary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Todos los pedidos (${stats.pedidosTotal})',
          accent: Palette.primary,
          icon: Icons.receipt_long_rounded,
          content: PedidosDetailContent(pedidos: stats.pedidosTodos),
        ),
      ),
      _StatCardData(
        'Pendientes', 'Por atender',
        Icons.timelapse_rounded,
        stats.pedidosPendientes,
        Palette.statsWarning,
        onTap: () => showDashboardDetail(
          context,
          title: 'Pedidos pendientes (${stats.pedidosPendientes})',
          accent: Palette.statsWarning,
          icon: Icons.timelapse_rounded,
          content: PedidosDetailContent(
            pedidos: stats.pedidosTodos
                .where((p) => normalizeEstado(p.estado) == kEstadoPendiente)
                .toList(),
          ),
        ),
      ),
      _StatCardData(
        'En camino', 'En reparto',
        Icons.local_shipping_rounded,
        stats.pedidosEnCamino,
        Palette.secondary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Pedidos en camino (${stats.pedidosEnCamino})',
          accent: Palette.secondary,
          icon: Icons.local_shipping_rounded,
          content: PedidosDetailContent(
            pedidos: stats.pedidosTodos
                .where((p) => normalizeEstado(p.estado) == kEstadoEnCamino)
                .toList(),
          ),
        ),
      ),
      _StatCardData(
        'Entregados', 'Completados',
        Icons.check_circle_rounded,
        stats.pedidosEntregados,
        Palette.statsSuccess,
        onTap: () => showDashboardDetail(
          context,
          title: 'Pedidos entregados (${stats.pedidosEntregados})',
          accent: Palette.statsSuccess,
          icon: Icons.check_circle_rounded,
          content: PedidosDetailContent(
            pedidos: stats.pedidosTodos
                .where((p) => normalizeEstado(p.estado) == kEstadoEntregado)
                .toList(),
          ),
        ),
      ),
      _StatCardData(
        'Ventas', 'Suma total (Bs)',
        Icons.payments_rounded,
        stats.ventasTotal.round(),
        Palette.primary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Detalle de ventas',
          accent: Palette.primary,
          icon: Icons.payments_rounded,
          content: PedidosDetailContent(pedidos: stats.pedidosTodos),
        ),
      ),
      _StatCardData(
        'Envío', 'Costo total (Bs)',
        Icons.delivery_dining_rounded,
        stats.costoEnvioTotal.round(),
        Palette.secondary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Costos de envío',
          accent: Palette.secondary,
          icon: Icons.delivery_dining_rounded,
          content: PedidosDetailContent(pedidos: stats.pedidosTodos, showEnvio: true),
        ),
      ),
      _StatCardData(
        'Productos', 'Catálogo',
        Icons.inventory_2_rounded,
        stats.productosTotal,
        Palette.secondary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Catálogo de productos (${stats.productosTotal})',
          accent: Palette.secondary,
          icon: Icons.inventory_2_rounded,
          content: ProductosDetailContent(productos: stats.productosTodos),
        ),
      ),
      _StatCardData(
        'Stock bajo', '≤ 5',
        Icons.warning_amber_rounded,
        stats.productosStockBajo,
        Palette.statsDanger,
        onTap: () => showDashboardDetail(
          context,
          title: 'Productos con stock bajo (${stats.productosStockBajo})',
          accent: Palette.statsDanger,
          icon: Icons.warning_amber_rounded,
          content: ProductosDetailContent(
            productos: stats.productosTodos.where((p) => p.stock <= 5).toList(),
            soloStockBajo: true,
          ),
        ),
      ),
      _StatCardData(
        'Usuarios', 'Registrados',
        Icons.people_alt_rounded,
        stats.usuariosTotal,
        Palette.statsNeutral,
        onTap: () => showDashboardDetail(
          context,
          title: 'Usuarios registrados (${stats.usuariosTotal})',
          accent: Palette.statsNeutral,
          icon: Icons.people_alt_rounded,
          content: UsuariosDetailContent(usuarios: stats.usuariosTodos),
        ),
      ),
      _StatCardData(
        'Repartidores', 'Registrados',
        Icons.badge_rounded,
        stats.repartidoresTotal,
        Palette.primary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Repartidores (${stats.repartidoresTotal})',
          accent: Palette.primary,
          icon: Icons.badge_rounded,
          content: RepartidoresDetailContent(repartidores: stats.repartidoresTodos),
        ),
      ),
      _StatCardData(
        'Banners', 'Total',
        Icons.campaign_rounded,
        stats.bannersTotal,
        Palette.secondary,
        onTap: () => showDashboardDetail(
          context,
          title: 'Banners (${stats.bannersTotal})',
          accent: Palette.secondary,
          icon: Icons.campaign_rounded,
          content: BannersDetailContent(banners: stats.bannersTodos),
        ),
      ),
      _StatCardData(
        'Banners activos', 'ACTIVO',
        Icons.verified_rounded,
        stats.bannersActivos,
        Palette.statsSuccess,
        onTap: () => showDashboardDetail(
          context,
          title: 'Banners activos (${stats.bannersActivos})',
          accent: Palette.statsSuccess,
          icon: Icons.verified_rounded,
          content: BannersDetailContent(
            banners: stats.bannersTodos
                .where((b) => b.estado.toUpperCase() == 'ACTIVO')
                .toList(),
            soloActivos: true,
          ),
        ),
      ),
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
  final VoidCallback? onTap;

  _StatCardData(
    this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.accent, {
    this.onTap,
  });
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.d});
  final _StatCardData d;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;

    return MouseRegion(
      cursor: d.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered && d.onTap != null
                ? d.accent.withValues(alpha: 0.06)
                : Palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered && d.onTap != null
                  ? d.accent.withValues(alpha: 0.5)
                  : Palette.primary.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered && d.onTap != null
                    ? d.accent.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _hovered ? 18 : 14,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Palette.ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    d.value.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 23,
                      color: Palette.ink,
                    ),
                  ),
                  if (d.onTap != null)
                    Text(
                      'Ver detalle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: d.accent.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
