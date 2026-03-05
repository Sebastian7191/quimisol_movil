import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class PredictivePrimaryButton extends StatelessWidget {
  const PredictivePrimaryButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_graph_rounded),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.primary,
        foregroundColor: Palette.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        elevation: 0,
      ),
    );
  }
}

class PredictiveMiniChip extends StatelessWidget {
  const PredictiveMiniChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? Palette.primary.withValues(alpha: 0.12)
        : Palette.card.withValues(alpha: 0.55);
    final bd = selected
        ? Palette.primary.withValues(alpha: 0.30)
        : Palette.primary.withValues(alpha: 0.14);
    final tx = selected ? Palette.primary : Palette.ink.withValues(alpha: 0.78);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
          border: Border.all(color: bd),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: tx,
          ),
        ),
      ),
    );
  }
}

class PredictiveMiniStatusPill extends StatelessWidget {
  const PredictiveMiniStatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class PredictiveInlineError extends StatelessWidget {
  const PredictiveInlineError({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.statsDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.statsDanger.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Palette.statsDanger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PredictiveMutedLine extends StatelessWidget {
  const PredictiveMutedLine({required this.text, this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          color: strong
              ? Palette.primary.withValues(alpha: 0.95)
              : Palette.ink.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}