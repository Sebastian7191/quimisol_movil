import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

/// Pide confirmación antes de cerrar sesión y ejecuta [onLogout] dentro del
/// mismo diálogo: mientras corre, el botón muestra un loading y el diálogo
/// no se puede cerrar ni volver a presionar.
///
/// Devuelve true si se cerró sesión (el llamador navega al login), false si
/// canceló o si [onLogout] falló (ya se mostró el error).
Future<bool> confirmarCerrarSesion(
  BuildContext context, {
  required Future<void> Function() onLogout,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LogoutDialog(onLogout: onLogout),
  );
  return ok == true;
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _saliendo = false;

  Future<void> _salir() async {
    setState(() => _saliendo = true);

    try {
      await widget.onLogout();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saliendo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Inténtalo de nuevo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras cierra sesión, el botón atrás no cierra el diálogo.
      canPop: !_saliendo,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          _saliendo
              ? 'Cerrando sesión...'
              : '¿Seguro que deseas cerrar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: _saliendo
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: _saliendo ? null : _salir,
            icon: _saliendo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Salir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.button,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Palette.button.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
