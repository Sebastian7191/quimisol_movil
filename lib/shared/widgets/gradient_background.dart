import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// Fondo con degradado y un overlay sutil de "spotlight" para dar profundidad.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.withSpotlight = true,
  });

  final Widget child;
  final bool withSpotlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Palette.gradientStart, Palette.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (withSpotlight)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.2, -0.6),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
