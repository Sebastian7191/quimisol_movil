import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';

/// Pantalla / sección de bloqueo para usuarios invitados.
///
/// Se muestra en tabs o acciones que requieren login. Incluye animación
/// sutil de entrada (fade + slide up).
class GuestLockView extends StatefulWidget {
  const GuestLockView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  State<GuestLockView> createState() => _GuestLockViewState();
}

class _GuestLockViewState extends State<GuestLockView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_ctrl);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goToLogin() {
    try {
      Modular.get<GuestStore>().exitGuest();
    } catch (_) {}
    Modular.to.navigate('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseIcon(icon: widget.icon),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink.withValues(alpha: 0.70),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _goToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.button,
                    foregroundColor: Palette.white,
                    elevation: 0,
                    shadowColor: Palette.button.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Iniciar sesión / Registrarse',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Es gratis y solo te toma un minuto.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.compact) return content;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }
}

/// Ícono con pulso muy sutil para llamar la atención sin distraer.
class _PulseIcon extends StatefulWidget {
  const _PulseIcon({required this.icon});
  final IconData icon;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 1.0 + t * 0.04;
        final alpha = 0.10 + t * 0.06;
        return Container(
          height: 104,
          width: 104,
          decoration: BoxDecoration(
            color: Palette.button.withValues(alpha: alpha),
            shape: BoxShape.circle,
          ),
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Icon(widget.icon, size: 46, color: Palette.button),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet de bloqueo invitado. Útil para acciones puntuales
/// (agregar al carrito, dar like, etc.).
Future<void> showGuestLockSheet(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.lock_outline_rounded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.white,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            GuestLockView(
              icon: icon,
              title: title,
              message: message,
              compact: true,
            ),
          ],
        ),
      ),
    ),
  );
}
