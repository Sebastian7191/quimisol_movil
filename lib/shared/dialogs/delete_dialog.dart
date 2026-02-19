import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Eliminar',
    this.cancelText = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.ink),
      ),
      content: Text(
        message,
        style: TextStyle(color: Palette.ink.withValues(alpha: 0.85)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.statsDanger,
            foregroundColor: Palette.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirmText,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
