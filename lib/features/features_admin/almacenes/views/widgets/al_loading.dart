import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AlmacenesLoadingGrid extends StatelessWidget {
  final int columns;
  final double aspect;

  const AlmacenesLoadingGrid({
    super.key,
    this.columns = 2,
    this.aspect = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: aspect,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 160, color: Palette.card),
            const SizedBox(height: 10),
            Container(height: 12, width: 120, color: Palette.card),
            const SizedBox(height: 12),
            Container(height: 10, width: 90, color: Palette.card),
            const Spacer(),
            Container(height: 10, width: double.infinity, color: Palette.card),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Container(height: 12, width: 100, color: Palette.card),
                Container(height: 12, width: 80, color: Palette.card),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
