import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'estados.dart';

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.codigo,
    required this.estado,
    required this.createdAt,
    required this.onClose,
  });

  final String codigo;
  final String estado;
  final DateTime? createdAt;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = colorForEstado(estado);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.96),
            color.withValues(alpha: 0.80),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #$codigo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt == null
                      ? '—'
                      : 'Creado: ${DateFormat('dd/MM/yyyy', 'es_BO').format(createdAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          EstadoPill(estado: estado),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}
