import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/admin_features/pedidos/controllers/detalle_controller.dart';

import 'warn_box.dart';

class RepartidorPickerWidget extends StatelessWidget {
  const RepartidorPickerWidget({
    super.key,
    required this.departamento,
    required this.almacenId,
    required this.valueUid,
    required this.valueNombre,
    required this.onChanged,
    required this.controller,
  });

  final String departamento;
  final String almacenId;
  final String? valueUid;
  final String? valueNombre;
  final Function(String? uid, String? nombre)? onChanged;
  final PedidoDetalleController controller;

  @override
  Widget build(BuildContext context) {
    final dep = departamento.trim();
    final alm = almacenId.trim();

    if (dep.isEmpty && alm.isEmpty) {
      return const WarnBox(text: 'Este pedido no tiene departamento ni almacenId.');
    }

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: controller.fetchRepartidores(departamento: dep, almacenId: alm),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _ghostField('Cargando repartidores…');
        }
        if (snap.hasError) {
          return WarnBox(text: 'Error: ${snap.error}');
        }

        final options = snap.data ?? [];
        if (options.isEmpty) {
          final extra = alm.isNotEmpty ? '(almacenId: "$alm")' : '(depto: "$dep")';
          return WarnBox(text: 'No hay repartidores disponibles. $extra');
        }

        final repartidoresMap = <String, String>{
          for (final doc in options)
            doc.id: ((doc.data()['name'] ??
                        doc.data()['nombre'] ??
                        'Repartidor')
                    .toString()
                    .trim()),
        };

        // ✅ Evita crash si valueUid no está en items
        final current = (valueUid != null && repartidoresMap.containsKey(valueUid))
            ? valueUid
            : null;

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Palette.fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: current,
              isExpanded: true,
              hint: Text(
                valueNombre?.trim().isNotEmpty == true
                    ? valueNombre!.trim()
                    : 'Seleccionar repartidor…',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Sin asignar —'),
                ),
                ...repartidoresMap.entries.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (uid) => onChanged!(uid, uid == null ? null : repartidoresMap[uid]),
            ),
          ),
        );
      },
    );
  }

  Widget _ghostField(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Palette.ink.withValues(alpha: 0.7),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
