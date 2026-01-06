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

  final _nameCtrl = TextEditingController();
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
    _nameCtrl.dispose();
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
      await _authService.signInWithGoogle();
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    return Scaffold(
      // Igual que en el LoginPage original
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Palette.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Modular.to.canPop()) {
              Modular.to.pop();
            } else {
              Modular.to.pushReplacementNamed('/home-guest');
            }
          },
        ),
      ),
      extendBodyBehindAppBar: true,

      body: GradientBackground(
        child: Center(
          // 👇 EXACTAMENTE igual a la estructura del LoginPage original:
          child: RoundedCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoginHeader(),
                  const SizedBox(height: 16),

                  // Nombre (solo registro)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isRegisterMode
                        ? Padding(
                            key: const ValueKey('nombre'),
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: TextFormField(
                              controller: _nameCtrl,
                              textCapitalization:
                                  TextCapitalization.words,
                              decoration: _pillDecoration(
                                hint: 'Ingrese su nombre completo',
                                icon: Icons.person,
                              ),
                              validator: (value) {
                                if (!_isRegisterMode) return null;
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Ingrese su nombre completo';
                                }
                                return null;
                              },
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('empty-nombre'),
                          ),
                  ),

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

                  // ¿Olvidaste tu contraseña?
                  if (!_isRegisterMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          if (_isLoading) return;
                          // navegación futura
                        },
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(color: Palette.primary),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Botón principal (tu AppButton ya con estilo Quimisol)
                  AppButton(
                    label:
                        _isRegisterMode ? 'REGISTRARSE' : 'INICIAR SESIÓN',
                    isLoading: _isLoading,
                    onPressed: () async {
                      if (_isLoading) return;
                      await _handleEmailSubmit();
                    },
                  ),

                  const SizedBox(height: 18),

                  // Redes sociales
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
                          ? '¿Ya tienes una cuenta? Iniciar sesión'
                          : '¿No tienes una cuenta? Crear cuenta',
                      style: const TextStyle(color: Palette.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
