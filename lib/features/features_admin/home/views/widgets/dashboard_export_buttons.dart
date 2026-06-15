import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../../controllers/dashboard_controller.dart';
import '../../data/dashboard_models.dart';
import '../../services/dashboard_export_service.dart';

class DashboardExportButtons extends StatefulWidget {
  const DashboardExportButtons({
    super.key,
    required this.stats,
    required this.range,
  });

  final DashboardStats stats;
  final DashboardRange range;

  @override
  State<DashboardExportButtons> createState() => _DashboardExportButtonsState();
}

class _DashboardExportButtonsState extends State<DashboardExportButtons> {
  bool _loadingExcel = false;
  bool _loadingPdf = false;

  String get _rangeLabel => switch (widget.range) {
        DashboardRange.today => 'Hoy',
        DashboardRange.last7 => 'Últimos 7 días',
        DashboardRange.last30 => 'Últimos 30 días',
        DashboardRange.all => 'Todo el tiempo',
      };

  Future<void> _exportExcel() async {
    setState(() => _loadingExcel = true);
    try {
      await DashboardExportService.exportExcel(
        stats: widget.stats,
        rangeLabel: _rangeLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar Excel: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingExcel = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _loadingPdf = true);
    try {
      await DashboardExportService.exportPDF(
        stats: widget.stats,
        rangeLabel: _rangeLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar PDF: $e'),
            backgroundColor: Palette.statsDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.download_rounded, color: Palette.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exportar datos',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Palette.ink,
                  ),
                ),
                Text(
                  'Descarga el reporte del período: $_rangeLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Palette.ink.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 10,
            children: [
              _ExportBtn(
                label: 'Excel',
                icon: Icons.table_chart_rounded,
                color: const Color(0xFF1D6F42),
                loading: _loadingExcel,
                onTap: _loadingExcel || _loadingPdf ? null : _exportExcel,
              ),
              _ExportBtn(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFDC2626),
                loading: _loadingPdf,
                onTap: _loadingPdf || _loadingExcel ? null : _exportPdf,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportBtn extends StatefulWidget {
  const _ExportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_ExportBtn> createState() => _ExportBtnState();
}

class _ExportBtnState extends State<_ExportBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: disabled
                ? widget.color.withValues(alpha: 0.08)
                : _hovered
                    ? widget.color
                    : widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled
                  ? widget.color.withValues(alpha: 0.20)
                  : widget.color.withValues(alpha: _hovered ? 1 : 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _hovered ? Palette.white : widget.color,
                  ),
                )
              else
                Icon(
                  widget.icon,
                  size: 17,
                  color: disabled
                      ? widget.color.withValues(alpha: 0.35)
                      : _hovered
                          ? Palette.white
                          : widget.color,
                ),
              const SizedBox(width: 7),
              Text(
                widget.loading ? 'Exportando…' : widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: disabled
                      ? widget.color.withValues(alpha: 0.35)
                      : _hovered
                          ? Palette.white
                          : widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
