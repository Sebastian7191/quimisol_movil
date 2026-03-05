import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class CategoriasLoadingTable extends StatelessWidget {
  const CategoriasLoadingTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
