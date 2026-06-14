import 'package:flutter/material.dart';

/// Fade + slide de entrada. Úsalo en cualquier widget que aparezca en pantalla.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.slideOffset = const Offset(0, 0.055),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _slide = Tween<Offset>(begin: widget.slideOffset, end: Offset.zero)
        .chain(CurveTween(curve: widget.curve))
        .animate(_ctrl);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Escala + sombra al hacer hover (desktop). Envuelve cualquier tarjeta interactiva.
class HoverScale extends StatefulWidget {
  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.022,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final double scale;
  final Duration duration;

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _ctrl.forward(),
        onExit: (_) => _ctrl.reverse(),
        child: ScaleTransition(scale: _anim, child: widget.child),
      );
}

/// Contador animado de 0 → value. Ideal para stat cards.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 950),
    this.curve = Curves.easeOutQuart,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: curve,
        builder: (_, v, __) => Text(
          '$prefix${v.round()}$suffix',
          style: style,
        ),
      );
}

/// Transición suave entre páginas/contenidos (fade + micro-slide).
class FadePageSwitcher extends StatelessWidget {
  const FadePageSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: child,
      );
}

/// Aplica stagger delay a cada hijo de una lista.
/// Uso: StaggerList(children: [...])
class StaggerList extends StatelessWidget {
  const StaggerList({
    super.key,
    required this.children,
    this.stepMs = 65,
    this.initialDelayMs = 0,
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = const Offset(0, 0.055),
  });

  final List<Widget> children;
  final int stepMs;
  final int initialDelayMs;
  final Duration duration;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          children.length,
          (i) => FadeSlideIn(
            delay: Duration(milliseconds: initialDelayMs + i * stepMs),
            duration: duration,
            slideOffset: slideOffset,
            child: children[i],
          ),
        ),
      );
}

/// Pulso suave (escala 1.0 → 1.05 → 1.0) para llamar la atención sobre un widget.
class PulseWidget extends StatefulWidget {
  const PulseWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Duration duration;

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
