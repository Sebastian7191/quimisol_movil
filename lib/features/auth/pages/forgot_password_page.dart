import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/buttons/app_button.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/widgets/gradient_background.dart';
import 'package:quimisol_movil/shared/widgets/rounded_card.dart';
import 'verify_code_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Ingresa un correo válido');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetCode(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerifyCodePage(email: email)),
      );
    } catch (e) {
      _showError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String error) {
    final msg = error.toLowerCase();
    if (msg.contains('not-found') || msg.contains('no existe')) {
      return 'No encontramos una cuenta con ese correo.';
    }
    if (msg.contains('network') || msg.contains('internet')) {
      return 'Sin conexión a internet. Verifica tu red.';
    }
    return 'No se pudo enviar el código. Intenta nuevamente.';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Palette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.lock_reset_rounded,
                        size: 56,
                        color: Palette.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recuperar contraseña',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tu correo y te enviaremos un código de 6 dígitos para restablecer tu contraseña.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _isLoading ? null : _sendCode(),
                        decoration: InputDecoration(
                          hintText: 'Ingresa tu correo',
                          filled: true,
                          fillColor: Palette.fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Palette.primary,
                          ),
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
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'ENVIAR CÓDIGO',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _sendCode,
                      ),
                    ],
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
