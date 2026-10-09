// lib/features/pasajeros_features/pedidos/widgets/rating_stars.dart

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class RatingStars extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const RatingStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            star <= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: Palette.button,
            size: size,
          ),
        );
      }),
    );
  }
}