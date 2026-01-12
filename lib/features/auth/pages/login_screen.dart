import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// UI
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../shared/widgets/gradient_background.dart';
import '../../../../../shared/widgets/rounded_card.dart';
import '../../../../../shared/buttons/social_button.dart';
import '../../../../../shared/buttons/app_button.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';

// Header con logo + “BIENVENIDOS”
import '../widgets/login_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Duration _socialDelay = Duration(seconds: 2);

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

  // ----------------- LÓGICA ORIGINAL -----------------

  Future<void> _handleEmailSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (_isRegisterMode) {
        // ✅ Manual: registro SIN nombre
        await _authService.registerWithEmail(email, password);
      } else {
        await _authService.signInWithEmail(email, password);
      }

      await _redirectByRole();
    } catch (e) {
      _showErrorSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final res = await _authService.signInWithGoogle();

      if (!mounted) return;

      // 🔥 SI NO COMPLETÓ PERFIL → COMPLETAR
      if (res.isNewUser) {
        Modular.to.navigate(
          '/perfil-completar',
          arguments: {'name': res.name, 'photoUrl': res.photoUrl},
        );
        return;
      }

      // 👉 Caso normal
      await _redirectByRole();
    } catch (e) {
      _showErrorSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _redirectByRole() async {
    final role = await _authService.getUserRole();
    if (!mounted) return;

    if (role == 'cliente') {
      Modular.to.navigate('/home-pasajero');
    } else if (role == 'conductor' || role == 'repartidor') {
      Modular.to.navigate('/home-conductor');
    } else {
      Modular.to.navigate('/home-pasajero');
    }
  }

  void _showErrorSnack(String message) {
    final clean = message.replaceAll('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(clean), backgroundColor: Colors.redAccent),
    );
  }

  // ----------------- SOLO UI -----------------

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

                        // Correo
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

                        // Contraseña
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SocialButton(
                              icon: FontAwesomeIcons.google,
                              onPressed: () async {
                                if (_isLoading) return;
                                await _handleGoogleLogin();
                              },
                            ),
                            const SizedBox(width: 10),
                            SocialButton(
                              icon: FontAwesomeIcons.facebookF,
                              onPressed: () async {
                                if (_isLoading) return;
                                await Future.delayed(_socialDelay);
                              },
                            ),
                            const SizedBox(width: 10),
                            SocialButton(
                              icon: FontAwesomeIcons.instagram,
                              onPressed: () async {
                                if (_isLoading) return;
                                await Future.delayed(_socialDelay);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

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
