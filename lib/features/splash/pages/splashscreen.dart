// lib/features/splash/splash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';
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
  late final AnimationController _enterCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _enterFade;
  late final Animation<double> _enterScale;

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

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterScale = Tween<double>(begin: 0.88, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_enterCtrl);
    _enterCtrl.forward();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );

    _init();
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    _loaderCtrl.dispose();
    _enterCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateWithFade(String route) async {
    if (!mounted) return;
    await _exitCtrl.reverse();
    if (!mounted) return;
    Modular.to.navigate(route);
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 900));

    final isLogged = await _authService.isLoggedIn();
    if (!mounted) return;

    // ✅ Sin sesión: entrar automáticamente como invitado al home de pasajero.
    if (!isLogged) {
      try {
        Modular.get<GuestStore>().enterAsGuest();
      } catch (_) {}
      await _navigateWithFade('/pasajero/');
      return;
    }

    // ✅ Con sesión: salir de modo invitado y redirigir por rol.
    try {
      Modular.get<GuestStore>().exitGuest();
    } catch (_) {}

    final role = await _authService.getUserRole();
    if (!mounted) return;

    if (role == 'admin' || role == 'superadmin') {
      await _navigateWithFade('/admin/');
      return;
    }

    if (role == 'cliente' || role == 'cliente_mayorista') {
      await _navigateWithFade('/pasajero/');
      return;
    }

    if (role == 'repartidor' || role == 'conductor') {
      await _navigateWithFade('/conductor/');
      return;
    }

    // Fallback: si el rol no es reconocido, lo dejamos navegar como invitado.
    try {
      Modular.get<GuestStore>().enterAsGuest();
    } catch (_) {}
    await _navigateWithFade('/pasajero/');
  }

  @override
  Widget build(BuildContext context) {
    final pinkBg = Palette.button;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _shineCtrl,
          _loaderCtrl,
          _enterCtrl,
          _exitCtrl,
        ]),
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

              Opacity(
                opacity: _exitCtrl.value,
                child: Center(
                  child: FadeTransition(
                    opacity: _enterFade,
                    child: ScaleTransition(
                      scale: _enterScale,
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
                                  color: Colors.black.withValues(alpha: 0.18),
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
                  ),
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