import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _prefKey = 'quimisol_session_token';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _sub;
  String? _localToken;
  String? _currentUid;

  /// Se activa en true cuando otra sesión del mismo usuario inicia en otro dispositivo/pestaña.
  final ValueNotifier<bool> sessionRevoked = ValueNotifier<bool>(false);

  /// Llamar tras un login exitoso.
  /// Genera un token nuevo, lo persiste en Firestore (invalidando sesiones anteriores) y empieza a escuchar.
  Future<void> registerNewSession(String uid) async {
    await _cancelSubscription();

    final token = _generateToken();
    _localToken = token;
    _currentUid = uid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, token);

    try {
      await _db.collection('usuarios').doc(uid).set(
        {'sessionToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('SessionService: error al escribir token de sesión: $e');
    }

    _startListening(uid);
  }

  /// Llamar al reabrir la app con un usuario ya autenticado.
  /// Solo escucha sin cambiar el token (no invalida otras sesiones).
  Future<void> resumeListening(String uid) async {
    // Ya estamos escuchando para este usuario: no hacer nada.
    if (_sub != null && _currentUid == uid) return;

    await _cancelSubscription();
    _currentUid = uid;

    final prefs = await SharedPreferences.getInstance();
    _localToken = prefs.getString(_prefKey);

    // Sin token local no podemos comparar; omitir la escucha.
    if (_localToken == null) return;

    _startListening(uid);
  }

  /// Llamar al hacer logout explícito — detiene la escucha y borra el token local.
  Future<void> stopSession() async {
    await _cancelSubscription();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Solo detiene la escucha sin borrar el token local.
  Future<void> stopListening() async {
    await _cancelSubscription();
  }

  void resetRevoked() {
    sessionRevoked.value = false;
  }

  void _startListening(String uid) {
    _sub = _db.collection('usuarios').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final remoteToken = snap.data()?['sessionToken'] as String?;
      if (remoteToken != null &&
          _localToken != null &&
          remoteToken != _localToken) {
        sessionRevoked.value = true;
      }
    });
  }

  Future<void> _cancelSubscription() async {
    await _sub?.cancel();
    _sub = null;
    _localToken = null;
    _currentUid = null;
  }

  String _generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$hex';
  }

  void dispose() {
    _sub?.cancel();
    sessionRevoked.dispose();
  }
}
