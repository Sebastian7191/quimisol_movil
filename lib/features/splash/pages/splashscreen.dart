// lib/features/splash/splash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AuthService _authService;

  late final AnimationController _shineCtrl;
  late final AnimationController _loaderCtrl;

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

    if (role == 'admin' || role == 'superadmin') {
      Modular.to.navigate('/admin');
      return;
    }

    if (role == 'cliente' || role == 'cliente_mayorista') {
      Modular.to.navigate('/home-pasajero');
      return;
    }

    if (role == 'repartidor' || role == 'conductor') {
      Modular.to.navigate('/home-conductor');
      return;
    }

    Modular.to.navigate('/login');
  }

  @override
  Widget build(BuildContext context) {
    final pinkBg = Palette.button;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_shineCtrl, _loaderCtrl]),
        builder: (_, __) {
          return Stack(
            children: [
              Container(color: pinkBg),

              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShinePainter(t: _shineCtrl.value),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Quimisol',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Productos e insumos químicos\nal alcance de tu negocio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
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

/// Brillo diagonal
class _ShinePainter extends CustomPainter {
  final double t;
  _ShinePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
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
          Colors.white.withOpacity(0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.rotate(-0.25);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) => oldDelegate.t != t;
}

/// Loader de 3 puntos
class _ThreeDotsLoading extends StatelessWidget {
  final double t;
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
            color: active ? Colors.white : Colors.white.withOpacity(0.35),
          ),
        );
      }),
    );
  }
}