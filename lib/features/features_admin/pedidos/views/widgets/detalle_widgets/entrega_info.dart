import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import 'empty_box.dart';

class EntregaInfo extends StatelessWidget {
  const EntregaInfo({
    super.key,
    required this.ubNombre,
    required this.direccion,
    required this.departamento,
  });

  final String ubNombre;
  final String direccion;
  final String departamento;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    Widget pill(String text, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Palette.fieldBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ink.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Palette.primary),
              const SizedBox(width: 6),
            ],
            Text(
              text.isEmpty ? '—' : text,
              style: TextStyle(
                color: ink.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (direccion.isEmpty)
          const EmptyBox(text: 'No se registró dirección.')
        else
          Text(
            direccion,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              height: 1.25,
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            pill(departamento.isEmpty ? '—' : departamento, icon: Icons.map_rounded),
            if (ubNombre.isNotEmpty) pill(ubNombre, icon: Icons.home_rounded),
          ],
        ),
      ],
    );
  }
}