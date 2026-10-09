import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class RepartidorLocationService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://quimisol-4f159-default-rtdb.firebaseio.com/',
  );

  Timer? _timer;

  // ✅ Estado interno para las condiciones
  Position? _lastSentPos;
  int _lastSentAtMs = 0;

  // 🔧 Config
  static const int _minSeconds = 10; // cada 10s
  static const double _minMeters = 50; // o si se mueve 50m
  static const Duration _tick = Duration(seconds: 2); // cada cuánto revisa

  DatabaseReference get _ref => _db.ref().child('repartidores');

  Future<void> start({required String uid}) async {
    stop();
    debugPrint('🚀 START tracking repartidor: $uid');

    // reset de estado interno
    _lastSentPos = null;
    _lastSentAtMs = 0;

    final enabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('GPS enabled: $enabled');
    if (!enabled) return;

    var perm = await Geolocator.checkPermission();
    debugPrint('Permission: $perm');

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      debugPrint('Permission after request: $perm');
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint('❌ Permiso GPS denegado');
      return;
    }

    debugPrint('📡 Permisos OK, iniciando timer');

    _timer = Timer.periodic(_tick, (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
        );

        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // --- Condición A: pasaron 10s ---
        final bool byTime =
            (_lastSentAtMs == 0) || (nowMs - _lastSentAtMs >= _minSeconds * 1000);

        // --- Condición B: se movió 50m ---
        final bool byDistance;
        if (_lastSentPos == null) {
          byDistance = true; // primera vez, enviamos
        } else {
          final d = Geolocator.distanceBetween(
            _lastSentPos!.latitude,
            _lastSentPos!.longitude,
            pos.latitude,
            pos.longitude,
          );
          byDistance = d >= _minMeters;
          // print('📏 Distancia desde último envío: ${d.toStringAsFixed(1)}m');
        }

        if (!byTime && !byDistance) {
          // No cumple ninguna condición, no enviamos.
          return;
        }

        debugPrint(
          '📤 Enviando por ${byTime ? "TIEMPO" : ""}${(byTime && byDistance) ? " + " : ""}${byDistance ? "DISTANCIA" : ""}'
          ' | 📍 ${pos.latitude}, ${pos.longitude}',
        );

        await _ref.child(uid).set({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'updatedAt': nowMs,
        });

        // actualizar últimos enviados
        _lastSentPos = pos;
        _lastSentAtMs = nowMs;

        debugPrint('✅ Ubicación enviada a RTDB');
      } catch (e) {
        debugPrint('❌ Error GPS/RTDB: $e');
      }
    });
  }

  void stop() {
    debugPrint('⏹️ STOP tracking');
    _timer?.cancel();
    _timer = null;
  }

  Future<void> clear(String uid) async {
    await _ref.child(uid).remove();
  }
}
