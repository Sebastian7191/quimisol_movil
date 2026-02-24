import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ Mantener una sola instancia
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

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
      // ✅ Fuerza limpiar selección previa (ayuda a mostrar chooser)
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // cancelado por el usuario
        return const GoogleLoginResult(isNewUser: false);
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final uid = userCred.user!.uid;

      final ref = _db.collection('usuarios').doc(uid);
      final doc = await ref.get();

      final data = doc.data();
      final bool isProfileCompleted =
          doc.exists && data?['profile_completed'] == true;

      // ✅ Si ya existe role, lo respetamos
      final String? existingRole = data?['role'] as String?;
      final bool hasRole = (existingRole != null && existingRole.isNotEmpty);

      final payload = <String, dynamic>{
        'email': userCred.user!.email,
        if (!hasRole) 'role': 'cliente',
        'profile_completed': isProfileCompleted ? true : false,
        if (userCred.user!.displayName != null) 'name': userCred.user!.displayName,
        if (userCred.user!.photoURL != null) 'photo': userCred.user!.photoURL,
        if (!doc.exists) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
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
      throw Exception('Error al iniciar con Google: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  LOGOUT
  // ──────────────────────────────────────────────
  @override
  Future<void> logout() async {
    // ✅ Primero Firebase
    await _auth.signOut();

    // ✅ Luego Google (disconnect fuerza mejor que vuelva a preguntar cuenta)
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
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
      default:
        return e.message ?? 'Error desconocido.';
    }
  }
}