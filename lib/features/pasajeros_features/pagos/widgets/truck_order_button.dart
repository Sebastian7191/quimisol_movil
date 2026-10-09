import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _TruckPhase { idle, loading, success }

/// Botón "Hacer pedido" con animación de entrega:
/// 1. El botón se derrite (con gotas) hasta quedar como una línea de camino.
/// 2. Aparece una caja, llega un camión, la caja cae dentro y el camión
///    "rueda en el sitio" sobre el camino mientras se crea el pedido.
/// 3. Si todo sale bien, el camión arranca y sale de la pantalla, el camino
///    vuelve a crecer hasta ser botón y aparece el mensaje de éxito.
///    Si falla, la animación se revierte y el botón vuelve a su estado inicial.
class TruckOrderButton extends StatefulWidget {
  final Color color;
  final bool enabled;

  /// Validaciones previas (síncronas). Si devuelve false no se anima nada.
  final bool Function()? validate;

  /// Crea el pedido. Devuelve true si salió bien.
  final Future<bool> Function() onSubmit;

  /// Se llama al terminar la animación de éxito.
  final VoidCallback onSuccess;

  final String label;
  final String successLabel;
  final double height;

  const TruckOrderButton({
    super.key,
    required this.color,
    required this.enabled,
    required this.onSubmit,
    required this.onSuccess,
    this.validate,
    this.label = 'Hacer pedido',
    this.successLabel = '¡Pedido realizado!',
    this.height = 58,
  });

  @override
  State<TruckOrderButton> createState() => _TruckOrderButtonState();
}

class _TruckOrderButtonState extends State<TruckOrderButton>
    with TickerProviderStateMixin {
  static const double _radius = 18;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _outro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  _TruckPhase _phase = _TruckPhase.idle;

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _outro.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_phase != _TruckPhase.idle || _intro.isAnimating) return;
    if (widget.validate != null && !widget.validate!()) return;

    HapticFeedback.lightImpact();
    setState(() => _phase = _TruckPhase.loading);
    _outro.value = 0;
    _loop.repeat();
    final introDone = _intro.forward(from: 0);

    bool ok;
    try {
      ok = await widget.onSubmit();
    } catch (_) {
      ok = false;
    }

    // La caja siempre termina de entrar al camión antes de seguir.
    await introDone;
    if (!mounted) return;

    if (!ok) {
      setState(() => _phase = _TruckPhase.idle);
      await _intro.reverse();
      _loop
        ..stop()
        ..value = 0;
      return;
    }

    setState(() => _phase = _TruckPhase.success);
    HapticFeedback.mediumImpact();
    await _outro.forward();
    _loop.stop();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) widget.onSuccess();
  }

  static double _iv(double t, double a, double b, [Curve c = Curves.linear]) {
    return c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _loop, _outro]),
      builder: (context, _) {
        final i = _intro.value;
        final o = _outro.value;
        final l = _loop.value;

        final busy = _phase != _TruckPhase.idle || i > 0;
        final active = widget.enabled || busy;
        final bg = active ? widget.color : Colors.black12;
        final fg = active ? Colors.white : Colors.black38;

        // 0 = botón entero, 1 = línea de camino.
        final melt =
            _iv(i, 0, 0.28, Curves.easeInQuad) *
            (1 - _iv(o, 0.45, 0.85, Curves.easeOutCubic));

        final labelT = _iv(i, 0, 0.18, Curves.easeIn);
        final successT = _iv(o, 0.7, 1, Curves.easeOutCubic);

        return Semantics(
          button: true,
          enabled: active,
          label: _phase == _TruckPhase.success
              ? widget.successLabel
              : widget.label,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  painter: _MeltPainter(
                    color: bg,
                    melt: melt,
                    radius: _radius,
                    lineY: _TruckScenePainter.roadY(widget.height),
                  ),
                ),
                if (i > 0)
                  CustomPaint(
                    painter: _TruckScenePainter(
                      accent: widget.color,
                      boxAppear: _iv(i, 0.25, 0.42, Curves.easeOutBack),
                      truckIn: _iv(i, 0.35, 0.68, Curves.easeOutCubic),
                      boxDrop: _iv(i, 0.7, 0.86, Curves.easeInCubic),
                      landBounce: math.sin(math.pi * _iv(i, 0.86, 1)),
                      truckOut: _iv(o, 0, 0.5, Curves.easeInCubic),
                      loop: l,
                      roadOpacity: _iv(i, 0.6, 0.9) * (1 - _iv(o, 0.3, 0.45)),
                      speedLines: math.sin(math.pi * _iv(o, 0.05, 0.55)),
                    ),
                  ),
                if (labelT < 1)
                  Opacity(
                    opacity: 1 - labelT,
                    child: Transform.translate(
                      // El texto "se cae" junto con el botón.
                      offset: Offset(0, 14 * labelT),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, color: fg),
                        ],
                      ),
                    ),
                  ),
                if (successT > 0)
                  Opacity(
                    opacity: successT,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - successT)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 0.6 + 0.4 * successT,
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.successLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(_radius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.enabled && !busy ? _handleTap : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fondo del botón. Con [melt] = 0 es el rectángulo redondeado normal; al
/// subir a 1 el borde superior cae ondulando, el inferior suelta gotas y
/// todo termina como una línea fina en [lineY].
class _MeltPainter extends CustomPainter {
  final Color color;
  final double melt;
  final double radius;
  final double lineY;

  _MeltPainter({
    required this.color,
    required this.melt,
    required this.radius,
    required this.lineY,
  });

  static const double _lineThickness = 4;

  // (posición x relativa, ancho, largo) de cada gota.
  static const List<(double, double, double)> _drips = [
    (0.10, 9, 7),
    (0.27, 13, 11),
    (0.46, 8, 6),
    (0.63, 14, 13),
    (0.81, 10, 8),
    (0.93, 7, 5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    if (melt <= 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        paint,
      );
      return;
    }

    final w = size.width;
    final h = size.height;
    final lineTop = lineY - _lineThickness / 2;
    final lineBottom = lineY + _lineThickness / 2;

    // El borde de arriba cae más rápido que el de abajo sube.
    final topBase = lineTop * melt;
    final bottomBase = h + (lineBottom - h) * Curves.easeOut.transform(melt);
    final goo = math.sin(math.pi * melt); // máximo a mitad del derretido
    final r = radius + (_lineThickness / 2 - radius) * melt;

    double corner(double x) {
      final d = math.min(x, w - x);
      if (d >= r) return 0;
      final dx = r - d;
      return r - math.sqrt(math.max(0, r * r - dx * dx));
    }

    double top(double x) {
      final wave =
          (0.5 + 0.5 * math.sin(x / w * math.pi * 5 + melt * 4)) * 7 * goo;
      return topBase + wave + corner(x);
    }

    double bottom(double x) {
      var drip = 0.0;
      for (final (fx, dw, len) in _drips) {
        final d = (x - fx * w) / dw;
        drip += math.exp(-d * d) * len * goo;
      }
      return bottomBase + drip - corner(x);
    }

    const step = 2.0;
    final path = Path()..moveTo(0, top(0));
    for (double x = step; x <= w; x += step) {
      path.lineTo(x, top(x));
    }
    path.lineTo(w, top(w));
    for (double x = w; x >= 0; x -= step) {
      final b = bottom(x);
      path.lineTo(x, math.max(b, top(x) + _lineThickness * melt));
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MeltPainter old) =>
      old.melt != melt || old.color != color || old.lineY != lineY;
}

class _TruckScenePainter extends CustomPainter {
  final Color accent;
  final double boxAppear; // 0..1 (puede pasar de 1 por easeOutBack)
  final double truckIn; // 0 fuera a la izquierda, 1 centrado
  final double boxDrop; // 0 flotando, 1 dentro del camión
  final double landBounce; // 0..1 golpe al caer la caja
  final double truckOut; // 0 centrado, 1 fuera a la derecha
  final double loop; // 0..1 ciclo continuo (ruedas, camino, vaivén)
  final double roadOpacity;
  final double speedLines;

  _TruckScenePainter({
    required this.accent,
    required this.boxAppear,
    required this.truckIn,
    required this.boxDrop,
    required this.landBounce,
    required this.truckOut,
    required this.loop,
    required this.roadOpacity,
    required this.speedLines,
  });

  static const double _cargoW = 36;
  static const double _cargoH = 21;
  static const double _cabW = 17;
  static const double _cabH = 15;
  static const double _gap = 2;
  static const double _truckW = _cargoW + _gap + _cabW;
  static const double _wheelR = 4.5;
  static const double _boxS = 14;
  static const Color _wheelColor = Color(0xFF263238);
  static const Color _boxColor = Color(0xFFFFB74D);
  static const Color _boxTape = Color(0xFFE08E2B);

  static double _wheelCy(double h) => h / 2 + 14;

  /// Centro vertical de la línea de camino en la que se derrite el botón.
  static double roadY(double h) => _wheelCy(h) + _wheelR + 2;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final wheelCy = _wheelCy(size.height);
    final bodyBottom = wheelCy - 1;
    final cargoTop = bodyBottom - _cargoH;

    final startX = -_truckW - 20;
    final restX = cx - _cargoW / 2;
    final endX = size.width + 20;
    final truckX =
        startX + (restX - startX) * truckIn + (endX - restX) * truckOut;

    // Vaivén del motor + golpe al recibir la caja.
    final idleBounce = (math.sin(loop * 2 * math.pi)).abs() * 1.0;
    final bodyDy = landBounce * 2.5 - idleBounce;

    _paintRoadDashes(canvas, size, roadY(size.height));
    _paintSpeedLines(canvas, truckX, cargoTop);

    // La caja se dibuja antes que el camión para que "entre" detrás del
    // furgón al caer.
    if (boxDrop < 1 && boxAppear > 0) {
      final hoverTop = cargoTop - _boxS - 2;
      final insideTop = cargoTop + 3 + bodyDy;
      final boxTop = hoverTop + (insideTop - hoverTop) * boxDrop;
      _paintBox(canvas, Offset(cx, boxTop + _boxS / 2), boxAppear);
    }

    _paintTruck(canvas, truckX, bodyBottom + bodyDy, wheelCy);
  }

  /// Marcas blancas que corren sobre la línea derretida para dar sensación
  /// de movimiento.
  void _paintRoadDashes(Canvas canvas, Size size, double y) {
    if (roadOpacity <= 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 * roadOpacity)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 8.0;
    const period = 20.0;
    final shift = loop * period;
    for (double x = -period; x < size.width + period; x += period) {
      final sx = x - shift;
      canvas.drawLine(Offset(sx, y), Offset(sx + dash, y), paint);
    }
  }

  void _paintSpeedLines(Canvas canvas, double truckX, double cargoTop) {
    if (speedLines <= 0) return;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.6 * speedLines)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const lines = [(4.0, 16.0), (10.0, 10.0), (16.0, 20.0)];
    for (final (dy, len) in lines) {
      final y = cargoTop + dy;
      final right = truckX - 5;
      canvas.drawLine(
        Offset(right - len * speedLines, y),
        Offset(right, y),
        paint,
      );
    }
  }

  void _paintBox(Canvas canvas, Offset center, double scale) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _boxS,
      height: _boxS,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
      Paint()..color = _boxColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 3, height: _boxS),
      Paint()..color = _boxTape,
    );
    canvas.restore();
  }

  void _paintTruck(Canvas canvas, double x, double bodyBottom, double wheelCy) {
    final body = Paint()..color = accent;
    final cabColor = Color.lerp(accent, Colors.black, 0.18)!;

    // Chasis
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2, bodyBottom - 3, _truckW - 2, 4),
        const Radius.circular(2),
      ),
      Paint()..color = cabColor,
    );

    // Furgón
    final cargo = Rect.fromLTWH(x, bodyBottom - _cargoH, _cargoW, _cargoH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargo, const Radius.circular(3.5)),
      body,
    );
    // Franja de marca
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 5, cargo.center.dy - 1.5, _cargoW - 10, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Cabina con frente inclinado
    final cabL = x + _cargoW + _gap;
    final cabT = bodyBottom - _cabH;
    final cab = Path()
      ..moveTo(cabL, bodyBottom)
      ..lineTo(cabL, cabT + 2)
      ..quadraticBezierTo(cabL, cabT, cabL + 2, cabT)
      ..lineTo(cabL + _cabW - 7, cabT)
      ..lineTo(cabL + _cabW, cabT + 6)
      ..lineTo(cabL + _cabW, bodyBottom - 2)
      ..quadraticBezierTo(
        cabL + _cabW,
        bodyBottom,
        cabL + _cabW - 2,
        bodyBottom,
      )
      ..close();
    canvas.drawPath(cab, Paint()..color = cabColor);

    // Ventana
    final window = Path()
      ..moveTo(cabL + 7, cabT + 2.5)
      ..lineTo(cabL + _cabW - 7.8, cabT + 2.5)
      ..lineTo(cabL + _cabW - 3, cabT + 6.5)
      ..lineTo(cabL + 7, cabT + 6.5)
      ..close();
    canvas.drawPath(window, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Faro
    canvas.drawCircle(
      Offset(cabL + _cabW - 1.2, bodyBottom - 4.5),
      1.4,
      Paint()..color = _boxColor,
    );

    _paintWheel(canvas, Offset(x + 9, wheelCy));
    _paintWheel(canvas, Offset(cabL + _cabW - 6, wheelCy));
  }

  void _paintWheel(Canvas canvas, Offset c) {
    canvas.drawCircle(c, _wheelR, Paint()..color = _wheelColor);
    canvas.drawCircle(c, 1.8, Paint()..color = Colors.white);
    final a = loop * 2 * math.pi;
    final spoke = Offset(math.cos(a), math.sin(a)) * (_wheelR - 0.8);
    canvas.drawLine(
      c - spoke,
      c + spoke,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TruckScenePainter old) => true;
}
