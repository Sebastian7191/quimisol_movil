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
  Future<String?> getUserId();
  Future<void> logout();

  // ✅ Manual: SOLO email + password (sin nombre)
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);

  // ✅ Google devuelve si es nuevo + datos iniciales
  Future<GoogleLoginResult> signInWithGoogle();
}
