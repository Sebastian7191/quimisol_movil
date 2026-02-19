import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class EstadoEditor extends StatelessWidget {
  const EstadoEditor({
    super.key,
    required this.estadoActual,
    required this.value,
    required this.onChanged,
  });

  final String estadoActual;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    final options = <String>[
      normalizeEstado(estadoActual),
      if (normalizeEstado(estadoActual) == kEstadoPendiente) kEstadoAceptado,
    ].toList();

    String label(String v) {
      switch (normalizeEstado(v)) {
        case kEstadoAceptado:
          return 'Aceptado';
        case kEstadoPendiente:
          return 'Pendiente';
        case kEstadoEnCamino:
          return 'En camino';
        case kEstadoEntregado:
          return 'Entregado';
        case kEstadoCancelado:
          return 'Cancelado';
        default:
          return v;
      }
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Palette.white,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ink.withValues(alpha: 0.55),
          ),
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w900,
            fontSize: 12.8,
          ),
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? value),
          items: options
              .map(
                (e) =>
                    DropdownMenuItem<String>(value: e, child: Text(label(e))),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class EstadoPill extends StatelessWidget {
  const EstadoPill({super.key, required this.estado});
  final String estado;

  String _label(String s) {
    return s.replaceAll('_', ' ').toUpperCase();
  }

  Color _color(String s) {
    switch (s.toLowerCase().trim()) {
      case 'entregado':
        return Palette.statsSuccess;
      case 'cancelado':
        return Palette.statsDanger;
      case 'en camino':
      case 'encamino':
        return Palette.statsWarning;
      case 'aceptado':
        return Palette.secondary;
      case 'pendiente':
      default:
        return Palette.primary;
    }
  }

  IconData _icon(String s) {
    switch (s.toLowerCase().trim()) {
      case 'entregado':
        return Icons.check_circle_rounded;
      case 'cancelado':
        return Icons.cancel_rounded;
      case 'en camino':
      case 'encamino':
        return Icons.local_shipping_rounded;
      case 'aceptado':
        return Icons.verified_rounded;
      case 'pendiente':
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(estado), size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            _label(estado),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}