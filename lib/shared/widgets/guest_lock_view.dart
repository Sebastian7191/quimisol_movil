import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';

/// Pantalla / sección de bloqueo para usuarios invitados.
///
/// Se muestra en tabs o acciones que requieren login.
class GuestLockView extends StatelessWidget {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha:0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: Palette.button),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Palette.ink.withValues(alpha:0.70),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _goToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.button,
                foregroundColor: Palette.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'Iniciar sesión / Registrarse',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Es gratis y solo te toma un minuto.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Palette.ink.withValues(alpha:0.55),
            ),
          ),
        ],
      ),
    );

    if (compact) return content;

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
                color: Colors.black.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
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
