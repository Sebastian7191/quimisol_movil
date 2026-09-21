import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Gestiona la sesión activa única del usuario.
///
/// Al iniciar sesión (o al abrir la app con sesión activa), escribe un token
/// único en Firestore y escucha cambios. Si el token cambia desde otro
/// dispositivo o desde el admin web, emite [sessionInvalidated].
class SessionService {
  static final SessionService _instance = SessionService._();
  factory SessionService() => _instance;
  SessionService._();

  final _db = FirebaseFirestore.instance;

  String? _localToken;
  StreamSubscription<DocumentSnapshot>? _sub;
  bool _firstSnapshot = true;

  final _kickController = StreamController<void>.broadcast();

  /// Emite un evento cuando la sesión fue tomada por otro dispositivo.
  Stream<void> get sessionInvalidated => _kickController.stream;

  /// Escribe un nuevo [sessionToken] en Firestore y empieza a escuchar cambios.
  /// Si el token en Firestore cambia luego (otro dispositivo inició sesión),
  /// se emite un evento en [sessionInvalidated].
  Future<void> startSession(String uid) async {
    await stopListening();

    final token = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    _localToken = token;
    _firstSnapshot = true;

    try {
      await _db.collection('usuarios').doc(uid).set(
        {'sessionToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('SessionService: error al escribir token: $e');
    }

    _sub = _db
        .collection('usuarios')
        .doc(uid)
        .snapshots()
        .listen(_onSnapshot);
  }

  void _onSnapshot(DocumentSnapshot snap) {
    // Ignorar el primer snapshot: es el reflejo de nuestro propio write.
    if (_firstSnapshot) {
      _firstSnapshot = false;
      return;
    }
    if (_localToken == null) return;

    final data = snap.data() as Map<String, dynamic>?;
    final firestoreToken = data?['sessionToken'] as String?;

    if (firestoreToken != null && firestoreToken != _localToken) {
      debugPrint('SessionService: sesión invalidada (token cambió)');
      _kickController.add(null);
    }
  }

  /// Cancela el listener y limpia el token local.
  /// Llamar en logout o al recibir el kick.
  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
    _localToken = null;
    _firstSnapshot = true;
  }
}
