import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import 'pr_common_widgets.dart';

class PerProductList extends StatelessWidget {
  const PerProductList({
    super.key, 
    required this.perProduct,
    required this.showAll,
  });

  final List<dynamic> perProduct;
  final bool showAll;

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  String _urgenciaLabel(String v) {
    switch (v) {
      case 'high':
        return 'Alta';
      case 'med':
        return 'Media';
      case 'low':
        return 'Baja';
      default:
        return '—';
    }
  }

  Color _urgColor(String v) {
    switch (v) {
      case 'high':
        return Palette.statsDanger;
      case 'med':
        return Palette.statsWarning;
      case 'low':
        return Palette.statsSuccess;
      default:
        return Palette.ink.withValues(alpha: 0.45);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (perProduct.isEmpty) {
      return Text(
        'Sin productos.',
        style: TextStyle(
          color: Palette.ink.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final takeN = showAll ? 12 : 6;
    final items = perProduct.take(takeN).toList();

    return Column(
      children: items.map((e) {
        final m = (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{};

        final name = (m['name'] ?? '').toString().trim();
        final codigo = (m['codigo'] ?? '').toString().trim();
        final title = name.isNotEmpty
            ? name
            : (codigo.isNotEmpty ? 'Producto $codigo' : 'Producto');

        // Datos (convertimos a UI amigable)
        final forecast7d = _asInt(m['forecastUnits7d']);
        final coverDays = _asDouble(m['daysOfCover']);
        final restock = _asInt(m['restockQtySuggestion']);
        final urg = (m['urgency'] ?? '').toString();

        final urgLabel = _urgenciaLabel(urg);
        final urgColor = _urgColor(urg);

        String pronosticoText() {
          if (forecast7d <= 0) return 'Pronóstico semanal: —';
          return 'Pronóstico semanal: $forecast7d unidades';
        }

        String coberturaText() {
          if (coverDays <= 0) return 'Cobertura estimada: —';
          return 'Cobertura estimada: ${coverDays.toStringAsFixed(0)} días';
        }

        String reposicionText() {
          if (restock <= 0) return 'Reposición sugerida: —';
          return 'Reposición sugerida: $restock unidades';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.card.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Palette.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.primary.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Palette.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),

                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PredictiveMutedLine(text: pronosticoText()),
                      PredictiveMutedLine(text: coberturaText()),
                      PredictiveMutedLine(
                        text: reposicionText(),
                        strong: restock > 0,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Urgency pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: urgColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: urgColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    urgLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: urgColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}