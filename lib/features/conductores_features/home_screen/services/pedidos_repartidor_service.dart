import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef PedidoDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Pedidos asignados a un repartidor.
///
/// El repartidor puede estar en `repartidorUid` o en `repartidor_uid`
/// (según qué panel lo asignó). Esta app escribe los dos con el mismo valor;
/// si difieren, otro panel cambió solo uno, y ese es el repartidor actual.
class PedidosRepartidor {
  PedidosRepartidor._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Repartidor actual del pedido (resuelve campos en conflicto).
  static String asignadoA(Map<String, dynamic> d) {
    final camel = _s(d['repartidorUid']);
    final snake = _s(d['repartidor_uid']);
    if (snake.isNotEmpty && snake != camel) return snake;

    for (final otro in [_s(d['conductorUid']), _s(d['driverUid'])]) {
      if (otro.isNotEmpty && otro != camel) return otro;
    }
    return camel.isNotEmpty ? camel : snake;
  }

  /// Fecha de entrega programada (el nombre del campo varía según el panel).
  static DateTime? fechaEnvio(Map<String, dynamic> d) {
    for (final k in ['fecha_envio', 'fechaEnvio', 'fecha_entrega']) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
    }
    return null;
  }

  /// Pedidos cuyo repartidor actual es [uid], en vivo.
  static Stream<List<PedidoDoc>> stream(String uid) {
    final col = FirebaseFirestore.instance.collection('pedidos');
    final consultas = [
      col.where('repartidorUid', isEqualTo: uid),
      col.where('repartidor_uid', isEqualTo: uid),
    ];

    late final StreamController<List<PedidoDoc>> controller;
    final ultimos = List<List<PedidoDoc>?>.filled(consultas.length, null);
    final subs = <StreamSubscription>[];

    void emitir() {
      // Espera a que respondan las dos consultas para no "parpadear".
      if (ultimos.any((l) => l == null)) return;
      final porId = <String, PedidoDoc>{};
      for (final lista in ultimos) {
        for (final d in lista!) {
          porId[d.id] = d;
        }
      }
      controller.add(
        porId.values.where((d) => asignadoA(d.data()) == uid).toList(),
      );
    }

    controller = StreamController<List<PedidoDoc>>(
      onListen: () {
        for (var i = 0; i < consultas.length; i++) {
          subs.add(
            consultas[i].snapshots().listen((snap) {
              ultimos[i] = snap.docs;
              emitir();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );

    return controller.stream;
  }
}
