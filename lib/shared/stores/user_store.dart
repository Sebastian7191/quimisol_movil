import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/shared/models/app_user.dart';
import 'package:quimisol_movil/core/services/session/session_service.dart';

class UserStore {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _session = SessionService();

  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  bool _wasKicked = false;
  bool get wasKicked => _wasKicked;
  void resetKicked() => _wasKicked = false;

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription? _kickSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  // Rol de la emisión anterior; null = primera emisión (no navegar todavía).
  String? _lastRole;

  UserStore() {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    _kickSub = _session.sessionInvalidated.listen((_) => _handleSessionKicked());
  }

  Future<void> _onAuthChanged(fb.User? fbUser) async {
    _userDocSub?.cancel();
    _userDocSub = null;
    _lastRole = null;

    if (fbUser == null) {
      user.value = null;
      return;
    }

    await _session.startSession(fbUser.uid);

    _userDocSub = _db
        .collection('usuarios')
        .doc(fbUser.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        user.value = null;
        return;
      }

      final newUser = AppUser.fromMap(doc.id, doc.data()!);
      final newRole = newUser.role;
      final prevRole = _lastRole;

      _lastRole = newRole;
      user.value = newUser;

      // Primera emisión: solo cargar el usuario, la navegación inicial
      // la gestiona el Splash.
      if (prevRole == null) return;

      // El rol cambió en tiempo real → redirigir al home correspondiente.
      if (newRole != prevRole) {
        _navigateToRoleHome(newRole);
      }
    });
  }

  void _navigateToRoleHome(String? role) {
    final r = (role ?? '').toLowerCase();
    if (r == 'admin' || r == 'superadmin') {
      Modular.to.navigate('/admin/');
    } else if (r == 'repartidor' || r == 'conductor') {
      Modular.to.navigate('/conductor/');
    } else {
      Modular.to.navigate('/pasajero/');
    }
  }

  Future<void> _handleSessionKicked() async {
    await _session.stopListening();
    _wasKicked = true;
    await _auth.signOut();
    Modular.to.navigate('/auth/login');
  }

  void dispose() {
    _authSub?.cancel();
    _kickSub?.cancel();
    _userDocSub?.cancel();
    user.dispose();
  }
}
