import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../../controllers/dashboard_controller.dart';
import '../../data/dashboard_models.dart';
import '../../services/dashboard_export_service.dart';

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({
    super.key,
    required this.width,
    this.stats,
    this.range,
  });

  final double width;
  final DashboardStats? stats;
  final DashboardRange? range;

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  bool _loadingExcel = false;
  bool _loadingPdf = false;

  String get _rangeLabel => switch (widget.range) {
        DashboardRange.today => 'Hoy',
        DashboardRange.last7 => 'Últimos 7 días',
        DashboardRange.last30 => 'Últimos 30 días',
        DashboardRange.all => 'Todo el tiempo',
        null => 'Últimos 7 días',
      };

  Future<void> _exportExcel() async {
    if (widget.stats == null) return;
    setState(() => _loadingExcel = true);
    try {
      await DashboardExportService.exportExcel(
        stats: widget.stats!,
        rangeLabel: _rangeLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al exportar Excel: $e'),
          backgroundColor: Palette.statsDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingExcel = false);
    }
  }

  Future<void> _exportPdf() async {
    if (widget.stats == null) return;
    setState(() => _loadingPdf = true);
    try {
      await DashboardExportService.exportPDF(
        stats: widget.stats!,
        rangeLabel: _rangeLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al exportar PDF: $e'),
          backgroundColor: Palette.statsDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.width < 700;
    final hasStats = widget.stats != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          // Ícono
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

          // Título + subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: compact ? 19 : 23,
                    fontWeight: FontWeight.w900,
                    color: Palette.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pedidos, productos, usuarios, repartidores y banners',
                  style: TextStyle(
                    fontSize: compact ? 13.5 : 14.5,
                    color: Palette.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Botones de exportación
          if (!compact) ...[
            const SizedBox(width: 12),
            _HeaderExportBtn(
              label: 'Excel',
              icon: Icons.table_chart_rounded,
              loading: _loadingExcel,
              enabled: hasStats && !_loadingPdf,
              onTap: _exportExcel,
            ),
            const SizedBox(width: 8),
            _HeaderExportBtn(
              label: 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              loading: _loadingPdf,
              enabled: hasStats && !_loadingExcel,
              onTap: _exportPdf,
            ),
            const SizedBox(width: 12),
          ] else if (hasStats) ...[
            const SizedBox(width: 8),
            _HeaderExportIconBtn(
              icon: Icons.table_chart_rounded,
              tooltip: 'Exportar Excel',
              loading: _loadingExcel,
              enabled: !_loadingPdf,
              onTap: _exportExcel,
            ),
            const SizedBox(width: 6),
            _HeaderExportIconBtn(
              icon: Icons.picture_as_pdf_rounded,
              tooltip: 'Exportar PDF',
              loading: _loadingPdf,
              enabled: !_loadingExcel,
              onTap: _exportPdf,
            ),
            const SizedBox(width: 8),
          ],

          // Badge "Quimisol • Admin Web"
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
                      fontSize: 13.5,
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

// Botón completo (label + icon) para pantallas anchas
class _HeaderExportBtn extends StatefulWidget {
  const _HeaderExportBtn({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_HeaderExportBtn> createState() => _HeaderExportBtnState();
}

class _HeaderExportBtnState extends State<_HeaderExportBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered && active
                ? Palette.white.withValues(alpha: 0.28)
                : Palette.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Palette.white.withValues(alpha: active ? 0.85 : 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Palette.white,
                  ),
                )
              else
                Icon(
                  widget.icon,
                  size: 16,
                  color: Palette.white.withValues(alpha: active ? 1.0 : 0.45),
                ),
              const SizedBox(width: 6),
              Text(
                widget.loading ? 'Exportando…' : widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: Palette.white.withValues(alpha: active ? 1.0 : 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Botón solo ícono para pantallas compactas
class _HeaderExportIconBtn extends StatelessWidget {
  const _HeaderExportIconBtn({
    required this.icon,
    required this.tooltip,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled && !loading ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Palette.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Palette.white.withValues(alpha: 0.6)),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Palette.white),
                )
              : Icon(icon, size: 18, color: Palette.white.withValues(alpha: enabled ? 1 : 0.4)),
        ),
      ),
    );
  }
}
