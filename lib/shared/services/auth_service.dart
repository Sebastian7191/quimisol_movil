class GoogleLoginResult {
  final bool isNewUser;
  final String? name;
  final String? photoUrl;

  const GoogleLoginResult({
    required this.isNewUser,
    this.name,
    this.photoUrl,
  });
}

abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<String?> getUserRole();

  /// true si un cliente no completó su registro: no está marcado con
  /// `profile_completed == true` y le falta nombre, teléfono o al menos una
  /// ubicación. Admin y repartidores nunca pasan por este paso.
  Future<bool> needsProfileCompletion();
  Future<String?> getUserId();
  Future<void> logout();

  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);

  Future<GoogleLoginResult?> signInWithGoogle();

  Future<void> sendPasswordResetCode(String email);
  Future<void> verifyResetCode(String email, String code);
  Future<void> resetPasswordWithCode(String email, String code, String newPassword);
}