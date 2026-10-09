import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/pedidos/controllers/detalle_controller.dart';

import 'warn_box.dart';

class RepartidorPickerWidget extends StatefulWidget {
  const RepartidorPickerWidget({
    super.key,
    required this.pedidoId,
    required this.departamento,
    required this.almacenId,
    required this.fechaEnvio,
    required this.valueUid,
    required this.valueNombre,
    required this.onChanged,
    required this.controller,
  });

  final String pedidoId;
  final String departamento;
  final String almacenId;

  /// Fecha de envío elegida; se usa para marcar repartidores ocupados.
  final DateTime? fechaEnvio;
  final String? valueUid;
  final String? valueNombre;
  final Function(String? uid, String? nombre)? onChanged;
  final PedidoDetalleController controller;

  @override
  State<RepartidorPickerWidget> createState() => _RepartidorPickerWidgetState();
}

class _RepartidorPickerWidgetState extends State<RepartidorPickerWidget> {
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _repartidores;
  Future<Map<String, DateTime>>? _ocupados;

  @override
  void initState() {
    super.initState();
    _repartidores = widget.controller.fetchRepartidores(
      departamento: widget.departamento.trim(),
      almacenId: widget.almacenId.trim(),
    );
    _ocupados = _fetchOcupados();
  }

  @override
  void didUpdateWidget(covariant RepartidorPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fechaEnvio != widget.fechaEnvio) {
      _ocupados = _fetchOcupados();
    }
  }

  Future<Map<String, DateTime>>? _fetchOcupados() {
    final fecha = widget.fechaEnvio;
    if (fecha == null) return null;
    return widget.controller.fetchRepartidoresOcupados(
      fechaEnvio: fecha,
      excludePedidoId: widget.pedidoId,
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dep = widget.departamento.trim();
    final alm = widget.almacenId.trim();

    if (dep.isEmpty && alm.isEmpty) {
      return const WarnBox(text: 'Este pedido no tiene departamento ni almacenId.');
    }

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _repartidores,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _ghostField('Cargando repartidores…');
        }
        if (snap.hasError) {
          return WarnBox(text: 'Error: ${snap.error}');
        }

        final options = snap.data ?? [];
        if (options.isEmpty) {
          return WarnBox(
            text: dep.isNotEmpty
                ? 'No hay repartidores en $dep.'
                : 'No hay repartidores en el departamento de este pedido.',
          );
        }

        final repartidoresMap = <String, String>{
          for (final doc in options)
            doc.id: ((doc.data()['name'] ??
                        doc.data()['nombre'] ??
                        'Repartidor')
                    .toString()
                    .trim()),
        };

        return FutureBuilder<Map<String, DateTime>>(
          future: _ocupados,
          builder: (context, ocSnap) {
            final ocupados = ocSnap.data ?? const <String, DateTime>{};
            return _buildDropdown(repartidoresMap, ocupados);
          },
        );
      },
    );
  }

  Widget _buildDropdown(
    Map<String, String> repartidoresMap,
    Map<String, DateTime> ocupados,
  ) {
    final valueUid = widget.valueUid;
    final onChanged = widget.onChanged;

    // ✅ Evita crash si valueUid no está en items
    final current = (valueUid != null && repartidoresMap.containsKey(valueUid))
        ? valueUid
        : null;
    final currentOcupado = current == null ? null : ocupados[current];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Palette.fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: currentOcupado != null
                  ? Palette.statsDanger
                  : Palette.ink.withValues(alpha: 0.06),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: current,
              isExpanded: true,
              hint: Text(
                widget.valueNombre?.trim().isNotEmpty == true
                    ? widget.valueNombre!.trim()
                    : 'Seleccionar repartidor…',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Sin asignar —'),
                ),
                ...repartidoresMap.entries.map((e) {
                  final ocupadoEn = ocupados[e.key];
                  return DropdownMenuItem<String?>(
                    value: e.key,
                    // Ocupado: no se puede elegir (salvo que ya sea el actual).
                    enabled: ocupadoEn == null || e.key == current,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ocupadoEn == null
                                ? null
                                : TextStyle(
                                    color: Palette.ink.withValues(alpha: 0.45),
                                  ),
                          ),
                        ),
                        if (ocupadoEn != null) _ocupadoTag(ocupadoEn),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: onChanged == null
                  ? null
                  : (uid) =>
                      onChanged(uid, uid == null ? null : repartidoresMap[uid]),
            ),
          ),
        ),
        if (currentOcupado != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Este repartidor ya tiene otro pedido a las '
              '${_hhmm(currentOcupado)}. Elige otro o cambia la fecha.',
              style: const TextStyle(
                color: Palette.statsDanger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _ocupadoTag(DateTime en) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.statsDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Ocupado · ${_hhmm(en)}',
        style: const TextStyle(
          color: Palette.statsDanger,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
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
