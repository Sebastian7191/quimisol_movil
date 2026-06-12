import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// Botón "Agregar" estándar para los encabezados de las gestiones del
/// panel de administración. Unifica el estilo en todas las pantallas
/// (categorías, unidades, productos, almacenes, etc.).
///
/// Pensado para ir sobre el encabezado con degradado: pastilla blanca con
/// ícono y texto en color primario.
class HeaderAddButton extends StatelessWidget {
  const HeaderAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Palette.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 18,
              vertical: compact ? 10 : 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 20, color: Palette.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Palette.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
