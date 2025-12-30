import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'package:quimisol_movil/shared/models/app_user.dart';

class UserStore {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  StreamSubscription<fb.User?>? _authSub;

  UserStore() {
    // escuchar cambios de auth
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(fb.User? fbUser) async {
    if (fbUser == null) {
      user.value = null;
      return;
    }

    final doc = await _db.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) {
      user.value = null;
      return;
    }

    user.value = AppUser.fromMap(doc.id, doc.data()!);
  }

  void dispose() {
    _authSub?.cancel();
    user.dispose();
  }
}
