import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────
  //  LOGIN ESTADO
  // ──────────────────────────────────────────────
  @override
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  @override
  Future<String?> getUserId() async {
    return _auth.currentUser?.uid;
  }

  // ──────────────────────────────────────────────
  //  OBTENER ROL DEL USUARIO
  // ──────────────────────────────────────────────
  @override
  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('usuarios').doc(uid).get();

      if (!doc.exists) return null;

      return doc.data()?['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  //  LOGIN CON EMAIL
  // ──────────────────────────────────────────────
  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  REGISTRO CON EMAIL
  // ──────────────────────────────────────────────
  @override
  Future<void> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Crear el documento del usuario en Firestore
      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'email': email,
        'role': 'cliente', // valor por defecto
        'created_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  LOGIN CON GOOGLE
  // ──────────────────────────────────────────────
  @override
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn google = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await google.signIn();

      if (googleUser == null) return; // cancelado por el usuario

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      // Verificar si ya tiene documento en Firestore
      final userDoc = await _db
          .collection('usuarios')
          .doc(userCred.user!.uid)
          .get();

      if (!userDoc.exists) {
        // Crear usuario nuevo
        await _db.collection('usuarios').doc(userCred.user!.uid).set({
          'email': userCred.user!.email,
          'name': userCred.user!.displayName,
          'photo': userCred.user!.photoURL,
          'role': 'cliente', // por defecto
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  // ──────────────────────────────────────────────
  //  LOGOUT
  // ──────────────────────────────────────────────
  @override
  Future<void> logout() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // ──────────────────────────────────────────────
  //  MANEJO DE ERRORES DE FIREBASE
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
