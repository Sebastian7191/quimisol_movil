import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lleva qué pedidos del cliente cambiaron de estado desde la última vez que
/// los vio, para avisarle (punto en la pestaña Pedidos, aviso en la lista y
/// animación en el seguimiento).
///
/// Por cada pedido guarda en el celular el último estado que el cliente vio.
/// Un pedido que se ve por primera vez toma su estado actual como "visto":
/// solo los cambios posteriores cuentan como novedad.
class PedidosNovedadesStore extends ChangeNotifier {
  PedidosNovedadesStore._();
  static final PedidosNovedadesStore I = PedidosNovedadesStore._();

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pedidosSub;

  String _uid = '';

  /// pedidoId -> estado actual (normalizado).
  final Map<String, String> _actual = {};

  /// pedidoId -> último estado que el cliente vio (normalizado).
  final Map<String, String> _visto = {};

  static String normEstado(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  String get _prefsKey => 'pedidos_visto_$_uid';

  /// Empieza a escuchar (idempotente). Sigue los cambios de sesión.
  void init() {
    if (_authSub != null) return;
    _authSub = _auth.authStateChanges().listen((user) => _bind(user?.uid));
  }

  Future<void> _bind(String? uid) async {
    await _pedidosSub?.cancel();
    _pedidosSub = null;
    _actual.clear();
    _visto.clear();
    _uid = uid ?? '';

    if (_uid.isEmpty) {
      notifyListeners();
      return;
    }

    await _cargarVistos();

    _pedidosSub = _fire
        .collection('pedidos')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .listen((snap) {
          var nuevosVistos = false;

          _actual.clear();
          for (final d in snap.docs) {
            final estado = normEstado(
              (d.data()['estado'] ?? 'pendiente').toString(),
            );
            _actual[d.id] = estado;

            // Primera vez que vemos el pedido: su estado actual es la base.
            if (!_visto.containsKey(d.id)) {
              _visto[d.id] = estado;
              nuevosVistos = true;
            }
          }

          if (nuevosVistos) _guardarVistos();
          notifyListeners();
        }, onError: (_) {});
  }

  Future<void> _cargarVistos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) => _visto[k] = v.toString());
    } catch (_) {}
  }

  Future<void> _guardarVistos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_visto));
    } catch (_) {}
  }

  /// true si el pedido cambió de estado desde que el cliente lo vio.
  bool tieneNovedad(String pedidoId) {
    final actual = _actual[pedidoId];
    return actual != null && _visto[pedidoId] != actual;
  }

  /// Cantidad de pedidos con novedad (para el punto de la pestaña).
  int get cantidad => _actual.keys.where(tieneNovedad).length;

  /// Último estado visto (normalizado), o null si nunca se registró.
  String? estadoVisto(String pedidoId) => _visto[pedidoId];

  /// Marca el estado actual del pedido como visto.
  void marcarVisto(String pedidoId) {
    final actual = _actual[pedidoId];
    if (actual == null || _visto[pedidoId] == actual) return;
    _visto[pedidoId] = actual;
    _guardarVistos();
    notifyListeners();
  }
}
