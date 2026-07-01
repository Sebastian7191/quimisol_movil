import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../models/ai_parsed.dart';

class AiStatusPill extends StatelessWidget {
  const AiStatusPill({super.key, required this.status});
  final String status;

  Color _color() {
    final s = status.toLowerCase().trim();
    if (s == 'generating') return Palette.statsWarning;
    if (s == 'done') return Palette.statsSuccess;
    if (s == 'done_text') return Palette.statsWarning; // “parcial”
    if (s == 'error') return Palette.statsDanger;
    return Palette.ink.withValues(alpha: 0.45);
  }

  String _label() {
    final s = status.toLowerCase().trim();
    if (s == 'generating') return 'Generando…';
    if (s == 'done') return 'Listo';
    if (s == 'done_text') return 'Resumen';
    if (s == 'error') return 'Error';
    return 'IA';
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: c,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

class AiBox extends StatelessWidget {
  const AiBox({super.key, required this.ai});
  final AiParsed ai;

  @override
  Widget build(BuildContext context) {
    final st = ai.status.toLowerCase().trim();

    if (st == 'generating') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.card.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Palette.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Generando análisis ejecutivo…',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Palette.ink.withValues(alpha: 0.86),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (st == 'error') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.statsDanger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.statsDanger.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Palette.statsDanger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ai.error.isNotEmpty
                    ? 'No se pudo generar el análisis de IA.\n${ai.error}'
                    : 'No se pudo generar el análisis de IA.',
                style: const TextStyle(
                  color: Palette.statsDanger,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasAnything = ai.summary.isNotEmpty ||
        ai.insights.isNotEmpty ||
        ai.risks.isNotEmpty ||
        ai.actions.isNotEmpty;

    if (!hasAnything) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.card.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.primary.withValues(alpha: 0.12)),
        ),
        child: Text(
          'El análisis aún no está disponible.',
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.74),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final onlySummaryAndActions =
        ai.summary.isNotEmpty &&
        ai.actions.isNotEmpty &&
        ai.insights.isEmpty &&
        ai.risks.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ai.summary.isNotEmpty)
            AiSummaryCard(
              summary: ai.summary,
              isPartial: st == 'done_text',
            ),

          if (ai.insights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _AiSectionCard(
                title: 'Hallazgos clave',
                icon: Icons.lightbulb_outline_rounded,
                color: Palette.primary,
                items: ai.insights,
              ),
            ),

          if (ai.risks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _AiSectionCard(
                title: 'Riesgos detectados',
                icon: Icons.warning_amber_rounded,
                color: Palette.statsDanger,
                items: ai.risks,
              ),
            ),

          if (ai.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _AiSectionCard(
                title: onlySummaryAndActions
                    ? 'Recomendaciones principales'
                    : 'Acciones recomendadas',
                icon: Icons.task_alt_rounded,
                color: Palette.statsSuccess,
                items: ai.actions,
              ),
            ),

          if (st == 'done_text')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Se mostró un resumen recuperado automáticamente.',
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.60),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key, 
    required this.summary,
    required this.isPartial,
  });

  final String summary;
  final bool isPartial;

  @override
  Widget build(BuildContext context) {
    final badgeColor = isPartial ? Palette.statsWarning : Palette.primary;
    final badgeLabel = isPartial ? 'Resumen recuperado' : 'Resumen ejecutivo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.20)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            summary,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Palette.ink.withValues(alpha: 0.90),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
class _AiSectionCard extends StatelessWidget {
  const _AiSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: Palette.ink.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}