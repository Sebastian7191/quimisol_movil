
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class LoadingFancy extends StatelessWidget {
   const LoadingFancy({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            'Cargando usuarios…',
            style: TextStyle(
              color: ink.withValues(alpha: .6),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.query, required this.role});
  final String query;
  final String role;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withValues(alpha: .06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 44,
                color: ink.withValues(alpha: .35),
              ),
              const SizedBox(height: 10),
              Text(
                'Sin resultados',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Filtro: $role${query.isEmpty ? '' : ' • "$query"'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink.withValues(alpha: .55),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}