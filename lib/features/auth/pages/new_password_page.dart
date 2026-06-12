import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/core/services/notifications/fcm_token_service.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/core/utils/form_validators.dart';
import 'package:quimisol_movil/shared/buttons/app_button.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';
import 'package:quimisol_movil/shared/widgets/gradient_background.dart';
import 'package:quimisol_movil/shared/widgets/rounded_card.dart';

class NewPasswordPage extends StatefulWidget {
  final String email;
  final String code;

  const NewPasswordPage({super.key, required this.email, required this.code});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordCtrl.text;

    setState(() => _isLoading = true);
    try {
      await _authService.resetPasswordWithCode(
        widget.email,
        widget.code,
        password,
      );
      await FcmTokenService.upsertCurrentTokenForCurrentUser();
      FcmTokenService.listenTokenRefreshForCurrentUser();
      if (!mounted) return;
      await _redirectByRole();
    } catch (e) {
      _showError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _redirectByRole() async {
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

  String _friendlyError(String error) {
    final msg = error.toLowerCase();
    if (msg.contains('expirado') ||
        msg.contains('expired') ||
        msg.contains('deadline')) {
      return 'El código ha expirado. Vuelve a iniciar el proceso.';
    }
    if (msg.contains('utilizado') || msg.contains('precondition')) {
      return 'Este código ya fue utilizado. Solicita uno nuevo.';
    }
    if (msg.contains('incorrecto') || msg.contains('invalid-argument')) {
      return 'Código incorrecto. Vuelve al paso anterior.';
    }
    if (msg.contains('caracteres') ||
        msg.contains('mayúscula') ||
        msg.contains('número')) {
      return passwordRequirementsHint;
    }
    return 'No se pudo cambiar la contraseña. Intenta nuevamente.';
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
                          Icons.lock_outlined,
                          size: 56,
                          color: Palette.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nueva contraseña',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Palette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ingresa y confirma tu nueva contraseña.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          inputFormatters: passwordInputFormatters,
                          decoration: _pillDecoration(
                            hint: 'Nueva contraseña',
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
                          validator: validateNewPassword,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Text(
                              passwordRequirementsHint,
                              style: TextStyle(
                                color: Palette.ink.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          inputFormatters: passwordInputFormatters,
                          onFieldSubmitted: (_) =>
                              _isLoading ? null : _changePassword(),
                          decoration: _pillDecoration(
                            hint: 'Confirmar contraseña',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                          validator: (value) => validatePasswordConfirmation(
                            value,
                            _passwordCtrl.text,
                          ),
                        ),
                        const SizedBox(height: 28),
                        AppButton(
                          label: 'CAMBIAR CONTRASEÑA',
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _changePassword,
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
