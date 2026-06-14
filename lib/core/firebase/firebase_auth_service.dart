import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/core/services/session/session_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionService _sessionService;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  FirebaseAuthService(this._sessionService);

  // ──────────────────────────────────────────────
  //  ESTADO DE LOGIN
  // ──────────────────────────────────────────────
  @override
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  @override
  Future<String?> getUserId() async => _auth.currentUser?.uid;

  // ──────────────────────────────────────────────
  //  OBTENER ROL
  // ──────────────────────────────────────────────
  @override
  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  //  LOGIN EMAIL
  // ──────────────────────────────────────────────
  @override
  Future<void> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );

      final uid = cred.user?.uid;
      if (uid != null) {
        await _sessionService.registerNewSession(uid);
      }
    } on FirebaseAuthException catch (e) {
      if (_looksLikeGoogleOnlyAccount(e)) {
        throw Exception(
          'Este correo parece estar registrado con Google. '
          'Usa "Continuar con Google" o crea una contraseña con "¿Olvidaste tu contraseña?".',
        );
      }
      throw Exception(_firebaseError(e));
    }
  }

  bool _looksLikeGoogleOnlyAccount(FirebaseAuthException e) {
    return e.code == 'invalid-credential' ||
        e.code == 'invalid-login-credentials';
  }

  // ──────────────────────────────────────────────
  //  REGISTRO EMAIL (SIN NOMBRE)
  // ──────────────────────────────────────────────
  @override
  Future<void> registerWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );

      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'email': cleanEmail,
        'role': 'cliente',
        'profile_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Registrar sesión tras el registro
      await _sessionService.registerNewSession(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(
          'Este correo ya está registrado. '
          'Si te registraste con Google, usa "Continuar con Google".',
        );
      }
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  LOGIN GOOGLE (WEB + MÓVIL)
  // ──────────────────────────────────────────────
  @override
  Future<GoogleLoginResult> signInWithGoogle() async {
    try {
      UserCredential userCred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});

        try {
          userCred = await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request' ||
              e.code == 'popup-blocked') {
            return const GoogleLoginResult(isNewUser: false);
          }
          rethrow;
        }
      } else {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}

        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return const GoogleLoginResult(isNewUser: false);
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await _auth.signInWithCredential(credential);
      }

      final uid = userCred.user!.uid;

      final ref = _db.collection('usuarios').doc(uid);
      final doc = await ref.get();

      if (!doc.exists) {
        await _auth.signOut();
        if (!kIsWeb) {
          try {
            await _googleSignIn.disconnect();
          } catch (_) {
            try {
              await _googleSignIn.signOut();
            } catch (_) {}
          }
        }
        throw Exception('Tu cuenta de Google no está registrada en el sistema.');
      }

      final data = doc.data();
      final bool isProfileCompleted = data?['profile_completed'] == true;

      final String? existingRole = data?['role'] as String?;
      final bool hasRole = (existingRole != null && existingRole.isNotEmpty);

      final payload = <String, dynamic>{
        'email': userCred.user!.email,
        if (!hasRole) 'role': 'cliente',
        'profile_completed': isProfileCompleted ? true : false,
        if (userCred.user!.displayName != null) 'name': userCred.user!.displayName,
        if (userCred.user!.photoURL != null) 'photo': userCred.user!.photoURL,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await ref.set(payload, SetOptions(merge: true));

      // Registrar sesión única
      await _sessionService.registerNewSession(uid);

      return GoogleLoginResult(
        isNewUser: !isProfileCompleted,
        name: userCred.user!.displayName,
        photoUrl: userCred.user!.photoURL,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    } catch (e) {
      throw Exception('No se pudo iniciar sesión con Google: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  RESET PASSWORD
  // ──────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  LOGOUT
  // ──────────────────────────────────────────────
  @override
  Future<void> logout() async {
    await _sessionService.stopSession();

    await _auth.signOut();

    if (!kIsWeb) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
    }
  }

  // ──────────────────────────────────────────────
  //  ERRORES LEGIBLES
  // ──────────────────────────────────────────────
  String _firebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está habilitado.';
      default:
        return e.message ?? 'Error desconocido.';
    }
  }
}
