import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class FloatingActionButtonCustom extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const FloatingActionButtonCustom({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.backgroundColor = Palette.secButton, // rosa por defecto
    this.foregroundColor = Palette.white,     // morado por defecto
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: icon != null
          ? Icon(icon, size: 20)
          : null,
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}