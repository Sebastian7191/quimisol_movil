import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class LoadingTable extends StatelessWidget {
  final IconData icon;
  const LoadingTable({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 42,
                color: Palette.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}