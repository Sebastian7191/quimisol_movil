import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final compact = width < 700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Palette.primary.withValues(alpha: 0.95),
            Palette.secondary.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Palette.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.white.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.dashboard_rounded, color: Palette.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: Palette.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pedidos, productos, usuarios, repartidores y banners',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Palette.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Palette.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.white, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: Palette.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Quimisol • Admin Web',
                    style: TextStyle(
                      color: Palette.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}