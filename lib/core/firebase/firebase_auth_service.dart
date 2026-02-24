import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb; //agregue esto no me preguntes por que, es para detectar si esta en web o no...jaja el maldito me respondió

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
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  REGISTRO EMAIL (SIN NOMBRE)
  // ──────────────────────────────────────────────
  @override
  Future<void> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // ✅ Manual: NO guardamos name aquí
      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'email': email.trim(),
        'role': 'cliente',
        'profile_completed': false,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  LOGIN GOOGLE (RETORNA isNewUser + name + photo)
  // ──────────────────────────────────────────────
  @override
  Future<GoogleLoginResult> signInWithGoogle() async {
    try {
      UserCredential userCred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});

        userCred = await _auth.signInWithPopup(provider);
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

      // COMPROBAR QUE EXISTE EN TU SISTEMA
      if (!doc.exists) {
        // Cierra sesión para que no quede logueado en Firebase
        await _auth.signOut();
        if (!kIsWeb) await GoogleSignIn().signOut();

        throw Exception('Tu cuenta de Google no está registrada en el sistema.');
      }

      final data = doc.data();
      final bool isProfileCompleted = data?['profile_completed'] == true;

      // (Opcional) actualizar datos básicos sin tocar role
      final payload = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
        if (userCred.user!.displayName != null) 'name': userCred.user!.displayName,
        if (userCred.user!.photoURL != null) 'photo': userCred.user!.photoURL,
        if (userCred.user!.email != null) 'email': userCred.user!.email,
      };

      await ref.set(payload, SetOptions(merge: true));

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