import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../data/models/entrega_item.dart';

class EntregaTile extends StatelessWidget {
  final EntregaItem item;
  final String timeText;
  final VoidCallback onTap;

  const EntregaTile({
    super.key,
    required this.item,
    required this.timeText,
    required this.onTap,
  });

  // ⭐ estrellas
  Widget _stars(double rating) {
    final full = rating.floor().clamp(0, 5);
    final half = (rating - full) >= 0.5 ? 1 : 0;
    final empty = (5 - full - half).clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star_rounded, size: 18, color: Palette.button),
        if (half == 1)
          Icon(Icons.star_half_rounded, size: 18, color: Palette.button),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_outline_rounded, size: 18, color: Palette.button),
      ],
    );
  }

  // ✅ Color por estado
  Color _stateBg(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Palette.statsSuccess.withOpacity(0.18);
    if (x.contains('cancel') || x.contains('rechaz')) {
      return Palette.statsDanger.withOpacity(0.18);
    }
    if (x.contains('camino') || x.contains('ruta') || x.contains('proceso')) {
      return Colors.orange.withOpacity(0.18);
    }
    if (x.contains('pend')) return Colors.orange.withOpacity(0.14);
    return Palette.primary.withOpacity(0.12);
  }

  Color _stateText(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Palette.statsSuccess;
    if (x.contains('cancel') || x.contains('rechaz')) return Palette.statsDanger;
    if (x.contains('camino') || x.contains('ruta') || x.contains('proceso')) {
      return Colors.orange.shade800;
    }
    if (x.contains('pend')) return Colors.orange.shade800;
    return Palette.primary;
  }

  Widget _stateChip(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _stateBg(estado),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _stateText(estado),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = item.rating;
    final hasRating = rating != null && rating > 0;

    final subtitle = [
      if ((item.clienteNombre ?? '').isNotEmpty) item.clienteNombre!,
      if ((item.direccion ?? '').isNotEmpty) item.direccion!,
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black.withOpacity(0.06),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: Palette.primary.withOpacity(0.85),
              ),
            ),
            const SizedBox(width: 12),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + fecha
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.pedidoCodigo != null
                              ? 'Pedido ${item.pedidoCodigo}'
                              : 'Entrega',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Palette.ink.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Palette.ink.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ✅ Estado (chip)
                  _stateChip(item.estado),

                  const SizedBox(height: 8),

                  // Sub info
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Palette.ink.withOpacity(0.7),
                      ),
                    ),

                  // Total + Rating
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (item.total != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Palette.fieldBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            'Total: Bs ${item.total!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Palette.primary.withOpacity(0.85),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (hasRating) _stars(rating!),
                      if (!hasRating)
                        Text(
                          'Sin calificación',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Palette.ink.withOpacity(0.55),
                          ),
                        ),
                    ],
                  ),

                  // Comentario corto
                  if ((item.ratingComment ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“${item.ratingComment!.trim()}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Palette.ink.withOpacity(0.68),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
