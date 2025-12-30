// lib/shared/services/auth_service.dart
abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<String?> getUserRole();
  Future<String?> getUserId();
  Future<void> logout();

  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> signInWithGoogle();
}