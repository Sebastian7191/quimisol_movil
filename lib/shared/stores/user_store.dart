import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'package:quimisol_movil/shared/models/app_user.dart';
import 'package:quimisol_movil/core/services/session/session_service.dart';

class UserStore {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionService _sessionService;

  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  StreamSubscription<fb.User?>? _authSub;

  UserStore(this._sessionService) {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(fb.User? fbUser) async {
    if (fbUser == null) {
      user.value = null;
      await _sessionService.stopListening();
      return;
    }

    final doc = await _db.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) {
      user.value = null;
      return;
    }

    user.value = AppUser.fromMap(doc.id, doc.data()!);

    // Reanudar escucha de sesión al volver a abrir la app con usuario ya logueado.
    // Si el login fue reciente, registerNewSession ya arrancó el listener y este
    // llamado es un no-op (misma UID, listener ya activo).
    await _sessionService.resumeListening(fbUser.uid);
  }

  void dispose() {
    _authSub?.cancel();
    user.dispose();
  }
}
