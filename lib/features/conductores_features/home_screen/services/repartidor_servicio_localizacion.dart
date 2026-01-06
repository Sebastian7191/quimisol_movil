import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class RepartidorLocationService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://quimisol-4f159-default-rtdb.firebaseio.com/',
  );

  Timer? _timer;

  DatabaseReference get _ref => _db.ref().child('repartidores');

  Future<void> start({required String uid}) async {
    stop();
    print('🚀 START tracking repartidor: $uid');

    final enabled = await Geolocator.isLocationServiceEnabled();
    print('GPS enabled: $enabled');
    if (!enabled) return;

    var perm = await Geolocator.checkPermission();
    print('Permission: $perm');

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      print('Permission after request: $perm');
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      print('❌ Permiso GPS denegado');
      return;
    }

    print('📡 Permisos OK, iniciando timer');

    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
          );

          print('📍 Posición: ${pos.latitude}, ${pos.longitude}');

          await _ref.child(uid).set({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          print('✅ Ubicación enviada a RTDB');
        } catch (e) {
          print('❌ Error GPS/RTDB: $e');
        }
      },
    );
  }

  void stop() {
    print('⏹️ STOP tracking');
    _timer?.cancel();
    _timer = null;
  }

  Future<void> clear(String uid) async {
    await _ref.child(uid).remove();
  }
}
