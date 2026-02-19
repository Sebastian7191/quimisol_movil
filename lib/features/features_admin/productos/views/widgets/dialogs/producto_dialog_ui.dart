// lib/features/admin/productos/widgets/dialog/producto_dialog_ui.dart
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class ProductoDialogUI {
  static const r18 = BorderRadius.all(Radius.circular(18));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r12 = BorderRadius.all(Radius.circular(12));

  static Widget gap([double h = 12]) => SizedBox(height: h);

  static InputDecoration decor({
    required String label,
    String? hint,
    Widget? prefixIcon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: TextStyle(color: Palette.ink.withValues(alpha: 0.65)),
      filled: true,
      fillColor: Palette.fieldBg,
      prefixIcon: prefixIcon,
      border: const OutlineInputBorder(borderRadius: r14),
      enabledBorder: OutlineInputBorder(
        borderRadius: r14,
        borderSide: BorderSide(color: Palette.button.withValues(alpha: 0.20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r14,
        borderSide: BorderSide(
          color: Palette.primary.withValues(alpha: 0.65),
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      errorMaxLines: 2,
    );
  }

  static Widget sectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: r16,
        border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Palette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: r16,
        border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EmptyImagePlaceholder extends StatelessWidget {
  final String message;
  const EmptyImagePlaceholder({super.key, this.message = 'Sin imagen'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.fieldBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: Palette.ink.withValues(alpha: 0.35),
              size: 44,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.70),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
