import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenService {
  FcmTokenService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// ✅ Crea/guarda el token FCM SOLO si el usuario no tiene ninguno.
  /// Devuelve true si guardó token nuevo, false si no hizo falta o falló.
  static Future<bool> ensureTokenIfMissingForCurrentUser() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ FcmTokenService: no hay usuario logueado');
        return false;
      }

      final userRef = _db.collection('usuarios').doc(user.uid);
      final userSnap = await userRef.get();

      final data = userSnap.data() ?? {};
      final existingTokens = _readTokens(data['fcmTokens']);

      // ✅ Si ya tiene token(s), no hacer nada
      if (existingTokens.isNotEmpty) {
        debugPrint('ℹ️ FcmTokenService: el usuario ya tiene fcmTokens');
        return false;
      }

      // ✅ Pedir permisos (iOS / Android 13+)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint('⚠️ FcmTokenService: getToken() devolvió null/vacío');
        return false;
      }

      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FcmTokenService: token guardado en usuarios/${user.uid}');
      return true;
    } catch (e) {
      debugPrint('❌ FcmTokenService.ensureTokenIfMissingForCurrentUser error: $e');
      return false;
    }
  }

  /// ✅ Opcional: fuerza guardado del token actual (sin duplicar)
  static Future<bool> upsertCurrentTokenForCurrentUser() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return false;

      final userRef = _db.collection('usuarios').doc(user.uid);
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FcmTokenService: upsert token en usuarios/${user.uid}');
      return true;
    } catch (e) {
      debugPrint('❌ FcmTokenService.upsertCurrentTokenForCurrentUser error: $e');
      return false;
    }
  }

  /// ✅ Opcional: escuchar refresh de token y actualizar Firestore
  /// Llama esto una sola vez (ej. después del login o al abrir app).
  static void listenTokenRefreshForCurrentUser() {
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        final user = fb.FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final userRef = _db.collection('usuarios').doc(user.uid);
        await userRef.set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('🔄 FcmTokenService: token refrescado y guardado');
      } catch (e) {
        debugPrint('❌ Error en onTokenRefresh: $e');
      }
    });
  }

  static List<String> _readTokens(dynamic raw) {
    if (raw is! List) return <String>[];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
}