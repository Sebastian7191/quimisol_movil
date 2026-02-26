import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb; //agregue esto no me preguntes por que, es para detectar si esta en web o no...jaja la app se respondio sola

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );
    } on FirebaseAuthException catch (e) {
      // Mensaje para el caso típico: "Me registré con Google, pero intento entrar con contraseña"
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
    } on FirebaseAuthException catch (e) {
      // Si el correo ya existe (por Google u otro), guía al usuario
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
  //  LOGIN GOOGLE (WEB + MÓVIL) Requiere que el usuario exista en Firestore (usuarios/{uid})
  //  WEB: signInWithPopup
  //  MÓVIL: google_sign_in
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
        final google = GoogleSignIn(scopes: ['email']);
        final GoogleSignInAccount? googleUser = await google.signIn();

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

      // Solo deja entrar si existe en tu sistema
      if (!doc.exists) {
        await _auth.signOut();
        if (!kIsWeb) await GoogleSignIn().signOut();
        throw Exception('Tu cuenta de Google no está registrada en el sistema.');
      }

      final data = doc.data();
      final bool isProfileCompleted = data?['profile_completed'] == true;

      // Actualizar básicos
      await ref.set({
        'updated_at': FieldValue.serverTimestamp(),
        if (userCred.user!.displayName != null) 'name': userCred.user!.displayName,
        if (userCred.user!.photoURL != null) 'photo': userCred.user!.photoURL,
        if (userCred.user!.email != null) 'email': userCred.user!.email,
      }, SetOptions(merge: true));

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
  //  RESET PASSWORD (para que puedan entrar por email/clave)
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
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
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
      default:
        return e.message ?? 'Error desconocido.';
    }
  }
}