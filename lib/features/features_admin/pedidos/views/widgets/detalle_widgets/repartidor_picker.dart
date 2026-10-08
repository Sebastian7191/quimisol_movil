import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/pedidos/controllers/detalle_controller.dart';

import 'warn_box.dart';

/// Selector de repartidor. Si el pedido tiene fecha de envío, marca como
/// "Ocupado" (y no deja elegir) a los repartidores que ya tienen otro pedido
/// activo a menos de [PedidoDetalleController.ventanaOcupado] de esa hora.
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
  final DateTime? fechaEnvio;
  final String? valueUid;
  final String? valueNombre;
  final Function(String? uid, String? nombre)? onChanged;
  final PedidoDetalleController controller;

  @override
  State<RepartidorPickerWidget> createState() => _RepartidorPickerWidgetState();
}

class _RepartidorPickerWidgetState extends State<RepartidorPickerWidget> {
  // Futures guardados: si se crearan en build, cada setState del formulario
  // volvería a consultar Firestore.
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _repartidores;
  Future<Map<String, List<PedidoOcupado>>>? _ocupados;

  @override
  void initState() {
    super.initState();
    _cargarRepartidores();
    _cargarOcupados();
  }

  @override
  void didUpdateWidget(covariant RepartidorPickerWidget old) {
    super.didUpdateWidget(old);
    if (old.departamento != widget.departamento ||
        old.almacenId != widget.almacenId) {
      _cargarRepartidores();
    }
    if (old.fechaEnvio != widget.fechaEnvio ||
        old.pedidoId != widget.pedidoId) {
      _cargarOcupados();
    }
  }

  void _cargarRepartidores() {
    _repartidores = widget.controller.fetchRepartidores(
      departamento: widget.departamento.trim(),
      almacenId: widget.almacenId.trim(),
    );
  }

  void _cargarOcupados() {
    final fecha = widget.fechaEnvio;
    _ocupados = fecha == null
        ? null
        : widget.controller.fetchOcupados(
            fecha: fecha,
            excluirPedidoId: widget.pedidoId,
          );
  }

  @override
  Widget build(BuildContext context) {
    final dep = widget.departamento.trim();
    final alm = widget.almacenId.trim();

    if (dep.isEmpty && alm.isEmpty) {
      return const WarnBox(
        text: 'Este pedido no tiene departamento ni almacenId.',
      );
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
          final extra = alm.isNotEmpty
              ? '(almacenId: "$alm")'
              : '(depto: "$dep")';
          return WarnBox(text: 'No hay repartidores disponibles. $extra');
        }

        final repartidoresMap = <String, String>{
          for (final doc in options)
            doc.id:
                ((doc.data()['name'] ?? doc.data()['nombre'] ?? 'Repartidor')
                    .toString()
                    .trim()),
        };

        return FutureBuilder<Map<String, List<PedidoOcupado>>>(
          future: _ocupados,
          builder: (context, ocupSnap) {
            final verificando =
                _ocupados != null &&
                ocupSnap.connectionState == ConnectionState.waiting;
            final ocupados = ocupSnap.data ?? const {};

            return _buildDropdown(
              repartidoresMap: repartidoresMap,
              ocupados: ocupados,
              verificando: verificando,
              errorOcupados: ocupSnap.hasError,
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required Map<String, String> repartidoresMap,
    required Map<String, List<PedidoOcupado>> ocupados,
    required bool verificando,
    required bool errorOcupados,
  }) {
    final fecha = widget.fechaEnvio;
    final valueUid = widget.valueUid;

    // ✅ Evita crash si valueUid no está en items
    final current = (valueUid != null && repartidoresMap.containsKey(valueUid))
        ? valueUid
        : null;

    final choqueActual = current == null ? null : ocupados[current];

    String? nota;
    if (fecha == null) {
      nota = 'Elige la fecha de envío para ver qué repartidores están libres.';
    } else if (verificando) {
      nota = 'Verificando disponibilidad…';
    } else if (errorOcupados) {
      nota = 'No se pudo verificar la disponibilidad de los repartidores.';
    }

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
              color: choqueActual != null
                  ? Palette.statsDanger.withValues(alpha: 0.55)
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
              // Lo que se ve cerrado: solo el nombre.
              selectedItemBuilder: (_) => [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('— Sin asignar —'),
                ),
                ...repartidoresMap.values.map(
                  (nombre) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Sin asignar —'),
                ),
                ...repartidoresMap.entries.map((e) {
                  final choques = ocupados[e.key];
                  final ocupado = choques != null && choques.isNotEmpty;
                  return DropdownMenuItem<String?>(
                    value: e.key,
                    // Ocupado: no se puede elegir (salvo que ya sea el
                    // asignado, para no romper el valor actual).
                    enabled: !ocupado || e.key == current,
                    child: _RepartidorItem(
                      nombre: e.value,
                      ocupadoHasta: ocupado && fecha != null
                          ? choques.first.horaTexto(fecha)
                          : null,
                    ),
                  );
                }),
              ],
              onChanged: widget.onChanged == null
                  ? null
                  : (uid) => widget.onChanged!(
                      uid,
                      uid == null ? null : repartidoresMap[uid],
                    ),
            ),
          ),
        ),
        if (choqueActual != null &&
            choqueActual.isNotEmpty &&
            fecha != null) ...[
          const SizedBox(height: 8),
          _ChoqueBox(
            nombre: repartidoresMap[current] ?? 'El repartidor',
            choques: choqueActual,
            referencia: fecha,
          ),
        ] else if (nota != null) ...[
          const SizedBox(height: 6),
          Text(
            nota,
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
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

/// Fila del menú: nombre + etiqueta "Ocupado 14:30" si tiene otro pedido.
class _RepartidorItem extends StatelessWidget {
  const _RepartidorItem({required this.nombre, this.ocupadoHasta});

  final String nombre;
  final String? ocupadoHasta;

  @override
  Widget build(BuildContext context) {
    final ocupado = ocupadoHasta != null;

    return Row(
      children: [
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ocupado
                  ? Palette.ink.withValues(alpha: 0.45)
                  : Palette.ink,
            ),
          ),
        ),
        if (ocupado) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Palette.statsDanger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Palette.statsDanger.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Ocupado $ocupadoHasta',
              style: const TextStyle(
                color: Palette.statsDanger,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso cuando el repartidor seleccionado choca con otro pedido (por
/// ejemplo, si se cambió la fecha después de asignarlo).
class _ChoqueBox extends StatelessWidget {
  const _ChoqueBox({
    required this.nombre,
    required this.choques,
    required this.referencia,
  });

  final String nombre;
  final List<PedidoOcupado> choques;
  final DateTime referencia;

  @override
  Widget build(BuildContext context) {
    final detalle = choques
        .map((c) {
          final cod = c.codigo.isEmpty ? '' : '#${c.codigo} ';
          return '$cod(${c.horaTexto(referencia)})';
        })
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.statsDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.statsDanger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 18,
            color: Palette.statsDanger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$nombre ya tiene otro pedido a esa hora: $detalle.',
              style: const TextStyle(
                color: Palette.statsDanger,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
