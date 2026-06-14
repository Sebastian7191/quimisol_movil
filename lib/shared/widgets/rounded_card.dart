import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

class RoundedCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const RoundedCard({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      shadowColor: Colors.black12,
      color: color ?? Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: child,
      ),
    );
  }
}
