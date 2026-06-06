import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// UI
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../shared/widgets/gradient_background.dart';
import '../../../../../shared/widgets/rounded_card.dart';
import '../../../../../shared/buttons/app_button.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';
import 'package:quimisol_movil/core/services/notifications/fcm_token_service.dart';

// Header con logo + “BIENVENIDOS”
import '../widgets/login_header.dart';
import 'forgot_password_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (_isRegisterMode) {
        await _authService.registerWithEmail(email, password);
      } else {
        await _authService.signInWithEmail(email, password);
      }

      await FcmTokenService.ensureTokenIfMissingForCurrentUser();
      await _redirectByRole();
    } catch (e) {
      _showErrorSnack(_getFriendlyAuthMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final res = await _authService.signInWithGoogle();

      // ✅ Usuario canceló Google
      if (res == null) {
        return;
      }

      await FcmTokenService.ensureTokenIfMissingForCurrentUser();

      if (!mounted) return;

      if (res.isNewUser) {
        Modular.to.navigate(
          '/auth/perfil-completar',
          arguments: {'name': res.name, 'photoUrl': res.photoUrl},
        );
        return;
      }

      await _redirectByRole();
    } catch (e) {
      _showErrorSnack(_getFriendlyAuthMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGuestLogin() {
    Modular.get<GuestStore>().enterAsGuest();
    Modular.to.navigate('/pasajero/');
  }

  Future<void> _redirectByRole() async {
    // ✅ Si el usuario llega a login real, salimos del modo invitado.
    try {
      Modular.get<GuestStore>().exitGuest();
    } catch (_) {}

    final role = await _authService.getUserRole();
    if (!mounted) return;

    if (role == 'admin' || role == 'superadmin') {
      Modular.to.navigate('/admin/');
      return;
    }

    if (role == 'cliente') {
      Modular.to.navigate('/pasajero/');
      return;
    }

    if (role == 'conductor' || role == 'repartidor') {
      Modular.to.navigate('/conductor/');
      return;
    }

    Modular.to.navigate('/pasajero/');
  }

  String _getFriendlyAuthMessage(String error) {
    final message = error.toLowerCase();

    if (message.contains('wrong-password') ||
        message.contains('invalid-credential') ||
        message.contains('credential is incorrect') ||
        message.contains('malformed or has expired')) {
      return 'Correo o contraseña incorrectos. Verifica tus datos e inténtalo nuevamente.';
    }

    if (message.contains('user-not-found')) {
      return 'No encontramos una cuenta con ese correo.';
    }

    if (message.contains('invalid-email')) {
      return 'El correo ingresado no es válido.';
    }

    if (message.contains('too-many-requests')) {
      return 'Se realizaron demasiados intentos. Espera un momento e inténtalo otra vez.';
    }

    if (message.contains('network-request-failed')) {
      return 'No se pudo conectar a internet. Revisa tu conexión.';
    }

    if (message.contains('email-already-in-use')) {
      return 'Ese correo ya está registrado. Intenta iniciar sesión.';
    }

    if (message.contains('weak-password')) {
      return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
    }

    if (message.contains('popup_closed') ||
        message.contains('popup-closed') ||
        message.contains('cancel') ||
        message.contains('cancelled')) {
      return 'Se canceló el inicio de sesión con Google.';
    }

    return 'No se pudo completar la operación. Inténtalo nuevamente.';
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Palette.fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      prefixIcon: Icon(icon, color: Palette.primary),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Palette.primary),
      ),
    );
  }

  Widget _googleFullButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(FontAwesomeIcons.google, size: 18, color: Palette.primary),
            SizedBox(width: 12),
            Text(
              'Continuar con Google',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    media.size.height -
                    media.padding.top -
                    media.padding.bottom,
              ),
              child: Center(
                child: RoundedCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LoginHeader(),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _pillDecoration(
                            hint: 'Ingrese su correo',
                            icon: Icons.email,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            if (!value.contains('@')) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: _pillDecoration(
                            hint: 'Ingrese su contraseña',
                            icon: Icons.lock,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu contraseña';
                            }
                            if (value.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        if (!_isRegisterMode)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                if (_isLoading) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(color: Palette.primary),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        AppButton(
                          label: _isRegisterMode
                              ? 'REGISTRARSE'
                              : 'INICIAR SESIÓN',
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (_isLoading) return;
                            await _handleEmailSubmit();
                          },
                        ),

                        const SizedBox(height: 18),

                        _googleFullButton(),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _handleGuestLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: Palette.primary,
                              backgroundColor: Palette.fieldBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                                side: BorderSide(
                                  color: Palette.primary.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Continuar como invitado',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        TextButton(
                          onPressed: () {
                            if (_isLoading) return;
                            setState(() => _isRegisterMode = !_isRegisterMode);
                          },
                          child: Text(
                            _isRegisterMode
                                ? '¿Ya tienes una cuenta? Logueate'
                                : '¿No tienes una cuenta? Registrate',
                            style: const TextStyle(color: Palette.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}