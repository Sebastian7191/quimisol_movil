// lib/features/splash/splash_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AuthService _authService;

  late final AnimationController _shineCtrl; // brillo que cruza
  late final AnimationController _loaderCtrl; // puntitos

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _init();
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 900));

    final isLogged = await _authService.isLoggedIn();
    if (!mounted) return;

    if (!isLogged) {
      Modular.to.navigate('/login');
      return;
    }

    final role = await _authService.getUserRole();
    if (!mounted) return;

    if (role == 'pasajero') {
      Modular.to.navigate('/home-pasajero');
    } else if (role == 'conductor' || role == 'trabajador') {
      Modular.to.navigate('/home-conductor');
    } else {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0A2E73);

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_shineCtrl, _loaderCtrl]),
        builder: (_, __) {
          return Stack(
            children: [
              // Fondo
              Container(color: primaryBlue),

              // Brillo que pasa por la pantalla
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShinePainter(t: _shineCtrl.value),
                  ),
                ),
              ),

              // Contenido centrado
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sticker blanco con rosa
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(child: _RedTulipSticker(size: 64)),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'quimisol_movil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu viaje, en un toque',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),

                    const SizedBox(height: 18),

                    _ThreeDotsLoading(t: _loaderCtrl.value),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Brillo diagonal que cruza toda la pantalla
class _ShinePainter extends CustomPainter {
  final double t; // 0..1
  _ShinePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // banda diagonal moviéndose
    final x = (-size.width) + (size.width * 2.2 * t);

    final rect = Rect.fromLTWH(
      x,
      -size.height * 0.2,
      size.width * 0.55,
      size.height * 1.4,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.rotate(-0.25); // leve diagonal
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) => oldDelegate.t != t;
}

/// Loader simple de 3 puntitos
class _ThreeDotsLoading extends StatelessWidget {
  final double t; // 0..1
  const _ThreeDotsLoading({required this.t});

  @override
  Widget build(BuildContext context) {
    final k = (t * 3).floor() % 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i == k;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 10 : 7,
          height: active ? 10 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white.withOpacity(0.30),
          ),
        );
      }),
    );
  }
}

/// Rosa tipo sticker (simple, estilo cartoon)
class _RedTulipSticker extends StatelessWidget {
  final double size;
  const _RedTulipSticker({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RedTulipStickerPainter(),
    );
  }
}

class _RedTulipStickerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final outline = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.07
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final red = Paint()..color = const Color(0xFFE31B23);
    final redDark = Paint()..color = const Color(0xFFB01218);
    final redDeep = Paint()..color = const Color(0xFF7A0D12);

    final green = Paint()..color = const Color(0xFF2E8B57);
    final greenDark = Paint()..color = const Color(0xFF1D6B3E);

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final cx = s.width * 0.5;
    final topY = s.height * 0.12;

    // ========= Tallo =========
    final stem = Path()
      ..moveTo(cx, s.height * 0.55)
      ..lineTo(cx, s.height * 0.92);

    canvas.drawPath(stem.shift(const Offset(1, 2)), shadow);
    canvas.drawPath(
      stem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E8B57), Color(0xFF1D6B3E)],
        ).createShader(Offset.zero & s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(stem, outline);

    // ========= Hoja izquierda =========
    final leafL = Path()
      ..moveTo(cx, s.height * 0.74)
      ..quadraticBezierTo(
        cx - s.width * 0.35,
        s.height * 0.70,
        cx - s.width * 0.30,
        s.height * 0.82,
      )
      ..quadraticBezierTo(
        cx - s.width * 0.10,
        s.height * 0.86,
        cx,
        s.height * 0.74,
      )
      ..close();

    // ========= Hoja derecha =========
    final leafR = Path()
      ..moveTo(cx, s.height * 0.66)
      ..quadraticBezierTo(
        cx + s.width * 0.34,
        s.height * 0.60,
        cx + s.width * 0.30,
        s.height * 0.74,
      )
      ..quadraticBezierTo(
        cx + s.width * 0.12,
        s.height * 0.80,
        cx,
        s.height * 0.66,
      )
      ..close();

    final leafPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E8B57), Color(0xFF1D6B3E)],
      ).createShader(Offset.zero & s);

    canvas.drawPath(leafL.shift(const Offset(1, 2)), shadow);
    canvas.drawPath(leafR.shift(const Offset(1, 2)), shadow);
    canvas.drawPath(leafL, leafPaint);
    canvas.drawPath(leafR, leafPaint);
    canvas.drawPath(leafL, outline);
    canvas.drawPath(leafR, outline);

    // ========= Flor (tulipán) =========
    // Base del tulipán
    final bud = Path()
      ..moveTo(cx, topY + s.height * 0.14)
      ..cubicTo(
        cx + s.width * 0.34,
        topY + s.height * 0.20,
        cx + s.width * 0.30,
        topY + s.height * 0.56,
        cx,
        topY + s.height * 0.60,
      )
      ..cubicTo(
        cx - s.width * 0.30,
        topY + s.height * 0.56,
        cx - s.width * 0.34,
        topY + s.height * 0.20,
        cx,
        topY + s.height * 0.14,
      )
      ..close();

    canvas.drawPath(bud.shift(const Offset(1, 2)), shadow);
    canvas.drawPath(bud, red);
    canvas.drawPath(bud, outline);

    // Pétalo central (punta)
    final centerPetal = Path()
      ..moveTo(cx, topY)
      ..quadraticBezierTo(
        cx + s.width * 0.12,
        topY + s.height * 0.22,
        cx,
        topY + s.height * 0.34,
      )
      ..quadraticBezierTo(cx - s.width * 0.12, topY + s.height * 0.22, cx, topY)
      ..close();

    canvas.drawPath(centerPetal, redDeep);
    canvas.drawPath(centerPetal, outline);

    // Sombra lateral derecha
    final shadeR = Path()
      ..moveTo(cx + s.width * 0.12, topY + s.height * 0.16)
      ..cubicTo(
        cx + s.width * 0.30,
        topY + s.height * 0.30,
        cx + s.width * 0.18,
        topY + s.height * 0.56,
        cx + s.width * 0.02,
        topY + s.height * 0.58,
      )
      ..close();

    canvas.drawPath(shadeR, redDark);

    // Brillito pequeño
    canvas.drawCircle(
      Offset(cx - s.width * 0.10, topY + s.height * 0.22),
      s.width * 0.05,
      Paint()..color = Colors.white.withOpacity(0.18),
    );

    // ========= Base verde (sépalos) =========
    final sepals = Path()
      ..moveTo(cx - s.width * 0.26, topY + s.height * 0.58)
      ..quadraticBezierTo(
        cx,
        topY + s.height * 0.50,
        cx + s.width * 0.26,
        topY + s.height * 0.58,
      )
      ..quadraticBezierTo(
        cx,
        topY + s.height * 0.64,
        cx - s.width * 0.26,
        topY + s.height * 0.58,
      )
      ..close();

    canvas.drawPath(sepals, green);
    canvas.drawPath(sepals, outline);
  }

  @override
  bool shouldRepaint(covariant _RedTulipStickerPainter oldDelegate) => false;
}

class _RoseStickerSimplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final outline = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.07
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final red = Paint()..color = const Color(0xFFE31B23);
    final redDark = Paint()..color = const Color(0xFFB01218);
    final green = Paint()..color = const Color(0xFF2E8B57);

    final cx = s.width * 0.5;

    // tallo
    final stem = Path()
      ..moveTo(cx, s.height * 0.55)
      ..lineTo(cx, s.height * 0.92);

    canvas.drawPath(
      stem,
      Paint()
        ..color = const Color(0xFF2E8B57)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(stem, outline);

    // base verde (sépalos)
    final base = Path()
      ..moveTo(cx - s.width * 0.26, s.height * 0.56)
      ..quadraticBezierTo(
        cx,
        s.height * 0.48,
        cx + s.width * 0.26,
        s.height * 0.56,
      )
      ..quadraticBezierTo(
        cx,
        s.height * 0.62,
        cx - s.width * 0.26,
        s.height * 0.56,
      )
      ..close();
    canvas.drawPath(base, green);
    canvas.drawPath(base, outline);

    // capullo (forma simple)
    final topY = s.height * 0.12;
    final bud = Path()
      ..moveTo(cx, topY)
      ..cubicTo(
        cx + s.width * 0.30,
        topY + s.height * 0.06,
        cx + s.width * 0.28,
        topY + s.height * 0.34,
        cx,
        topY + s.height * 0.48,
      )
      ..cubicTo(
        cx - s.width * 0.28,
        topY + s.height * 0.34,
        cx - s.width * 0.30,
        topY + s.height * 0.06,
        cx,
        topY,
      )
      ..close();

    canvas.drawPath(bud, red);
    canvas.drawPath(bud, outline);

    // sombra lateral
    final shade = Path()
      ..moveTo(cx + s.width * 0.14, topY + s.height * 0.12)
      ..cubicTo(
        cx + s.width * 0.28,
        topY + s.height * 0.26,
        cx + s.width * 0.18,
        topY + s.height * 0.44,
        cx + s.width * 0.02,
        topY + s.height * 0.46,
      )
      ..close();
    canvas.drawPath(shade, redDark);

    // espiral arriba
    final detail = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.04
      ..strokeCap = StrokeCap.round;

    final c = Offset(cx, topY + s.height * 0.18);
    final spiral = Path();
    for (int i = 0; i < 22; i++) {
      final tt = i / 21.0;
      final ang = tt * math.pi * 3.6;
      final rr = (s.width * 0.01) + tt * (s.width * 0.22);
      final p = c + Offset(math.cos(ang), math.sin(ang)) * rr;
      if (i == 0) {
        spiral.moveTo(p.dx, p.dy);
      } else {
        spiral.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(spiral, detail);
  }

  @override
  bool shouldRepaint(covariant _RoseStickerSimplePainter oldDelegate) => false;
}
