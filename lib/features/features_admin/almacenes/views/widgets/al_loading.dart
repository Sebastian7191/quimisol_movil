import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AlmacenesLoadingGrid extends StatelessWidget {
  const AlmacenesLoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withValues(alpha:  0.25)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 160, color: Palette.card),
            const SizedBox(height: 10),
            Container(height: 12, width: 100, color: Palette.card),
            const Spacer(),
            Row(
              children: [
                Container(height: 12, width: 90, color: Palette.card),
                const SizedBox(width: 16),
                Container(height: 12, width: 70, color: Palette.card),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
