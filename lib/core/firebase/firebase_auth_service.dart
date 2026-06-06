import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  @override
  Future<String?> getUserId() async => _auth.currentUser?.uid;

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

  @override
  Future<GoogleLoginResult?> signInWithGoogle() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // ✅ Canceló selección de cuenta: no navegar, no continuar
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user == null) {
        throw Exception('No se pudo obtener el usuario autenticado.');
      }

      final uid = user.uid;
      final ref = _db.collection('usuarios').doc(uid);
      final doc = await ref.get();
      final data = doc.data() ?? <String, dynamic>{};

      final bool isProfileCompleted =
          doc.exists && data['profile_completed'] == true;

      final String existingRole = (data['role'] ?? '').toString().trim();
      final bool hasRole = existingRole.isNotEmpty;

      final String existingName = (data['name'] ?? '').toString().trim();
      final String existingPhoto = (data['photo'] ?? '').toString().trim();

      final String googleName = (user.displayName ?? '').trim();
      final String googlePhoto = (user.photoURL ?? '').trim();
      final String googleEmail = (user.email ?? '').trim();

      final Map<String, dynamic> payload = {
        'email': googleEmail,
        if (!hasRole) 'role': 'cliente',
        'profile_completed': isProfileCompleted,
        if (existingName.isEmpty && googleName.isNotEmpty) 'name': googleName,
        if (existingPhoto.isEmpty && googlePhoto.isNotEmpty)
          'photo': googlePhoto,
        if (!doc.exists) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await ref.set(payload, SetOptions(merge: true));

      return GoogleLoginResult(
        isNewUser: !isProfileCompleted,
        name: existingName.isNotEmpty
            ? existingName
            : (googleName.isNotEmpty ? googleName : null),
        photoUrl: existingPhoto.isNotEmpty
            ? existingPhoto
            : (googlePhoto.isNotEmpty ? googlePhoto : null),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    } catch (e) {
      throw Exception('Error al iniciar con Google: $e');
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    try {
      final callable = _functions.httpsCallable('enviarCodigoRecuperacion');
      await callable.call({'email': email.trim().toLowerCase()});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al enviar el código');
    }
  }

  @override
  Future<void> verifyResetCode(String email, String code) async {
    try {
      final callable = _functions.httpsCallable('verificarCodigo');
      await callable.call({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Código incorrecto');
    }
  }

  @override
  Future<void> resetPasswordWithCode(String email, String code, String newPassword) async {
    try {
      final callable = _functions.httpsCallable('verificarYResetear');
      await callable.call({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: newPassword,
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al cambiar la contraseña');
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

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