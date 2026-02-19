import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../controllers/dashboard_controller.dart';

class DashboardFilters extends StatelessWidget {
  const DashboardFilters({
    super.key,
    required this.controller,
    required this.almacenes,
  });

  final DashboardController controller;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> almacenes;

  @override
  Widget build(BuildContext context) {
    final itemsAlm = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Todos los almacenes')),
      ...almacenes.map((d) {
        final m = d.data();
        return DropdownMenuItem<String?>(
          value: d.id,
          child: Text((m['nombre'] ?? d.id).toString()),
        );
      }),
    ];

    final estados = const <String?>[
      null,
      'pendiente',
      'aceptado',
      'en camino',
      'entregado',
      'cancelado',
    ];

    final departamentos = const <String?>[
      null,
      'Cochabamba',
      'La Paz',
      'Santa Cruz',
      'Oruro',
      'Potosí',
      'Chuquisaca',
      'Tarija',
      'Beni',
      'Pando',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chipRange(context),
          _drop(
            label: 'Estado',
            value: controller.estado,
            items: estados.map((e) {
              return DropdownMenuItem<String?>(
                value: e,
                child: Text(e ?? 'Todos los estados'),
              );
            }).toList(),
            onChanged: (v) => controller.setEstado(v),
          ),
          _drop(
            label: 'Departamento',
            value: controller.departamento,
            items: departamentos.map((d) {
              return DropdownMenuItem<String?>(
                value: d,
                child: Text(d ?? 'Todos los departamentos'),
              );
            }).toList(),
            onChanged: (v) => controller.setDepartamento(v),
          ),
          _drop(
            label: 'Almacén (productos/repartidores)',
            value: controller.almacenId,
            items: itemsAlm,
            onChanged: (v) => controller.setAlmacen(v),
          ),
          TextButton.icon(
            onPressed: controller.clear,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _chipRange(BuildContext context) {
    Widget chip(String t, DashboardRange r) {
      final sel = controller.range == r;
      return InkWell(
        onTap: () => controller.setRange(r),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Palette.primary.withValues(alpha: 0.14) : Palette.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sel ? Palette.primary.withValues(alpha: 0.35) : Palette.primary.withValues(alpha: 0.14)),
          ),
          child: Text(
            t,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: sel ? Palette.primary : Palette.ink.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip('Hoy', DashboardRange.today),
        chip('7 días', DashboardRange.last7),
        chip('30 días', DashboardRange.last30),
        chip('Todo', DashboardRange.all),
      ],
    );
  }

  Widget _drop({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 260,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Palette.card.withValues(alpha: 0.55),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            isExpanded: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
