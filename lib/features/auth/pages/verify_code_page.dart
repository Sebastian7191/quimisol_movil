import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/buttons/app_button.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/widgets/gradient_background.dart';
import 'package:quimisol_movil/shared/widgets/rounded_card.dart';
import 'new_password_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;

  const VerifyCodePage({super.key, required this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focuses = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _countdown = 600;
  int _resendCooldown = 60;

  Timer? _countdownTimer;
  Timer? _resendTimer;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
    _startCountdown();
    _startResendCooldown();

    for (int i = 0; i < 6; i++) {
      final index = i;
      _focuses[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          FocusScope.of(node.context!).requestFocus(_focuses[index - 1]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length < 6) {
      _showError('Ingresa el código completo de 6 dígitos');
      return;
    }
    if (_countdown == 0) {
      _showError('El código ha expirado. Solicita uno nuevo.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyResetCode(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewPasswordPage(email: widget.email, code: code),
        ),
      );
    } catch (e) {
      _showError(_friendlyError(e.toString()));
      _shakeCode();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _canResend = false;
      _resendCooldown = 60;
      _countdown = 600;
    });

    try {
      await _authService.sendPasswordResetCode(widget.email);
      if (!mounted) return;
      _clearCode();
      _startCountdown();
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código reenviado exitosamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) _showError('No se pudo reenviar el código');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) FocusScope.of(context).requestFocus(_focuses[0]);
  }

  void _shakeCode() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) FocusScope.of(context).requestFocus(_focuses[0]);
  }

  String _friendlyError(String error) {
    final msg = error.toLowerCase();
    if (msg.contains('incorrecto') || msg.contains('invalid-argument')) {
      if (RegExp(r'\d+ intento').hasMatch(msg)) {
        final match = RegExp(r'(\d+ intento\S*)').firstMatch(msg);
        return 'Código incorrecto. ${match?.group(1) ?? 'Intenta nuevamente'}.';
      }
      return 'Código incorrecto. Verifica e intenta nuevamente.';
    }
    if (msg.contains('expirado') || msg.contains('expired') || msg.contains('deadline')) {
      return 'El código ha expirado. Solicita uno nuevo.';
    }
    if (msg.contains('intentos') || msg.contains('exhausted')) {
      return 'Demasiados intentos fallidos. Solicita un nuevo código.';
    }
    if (msg.contains('utilizado') || msg.contains('precondition')) {
      return 'Este código ya fue utilizado. Solicita uno nuevo.';
    }
    return 'No se pudo verificar el código. Intenta nuevamente.';
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

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focuses[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Palette.ink,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Palette.fieldBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.primary, width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            FocusScope.of(context).requestFocus(_focuses[index + 1]);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final expired = _countdown == 0;

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
                        Icons.mark_email_read_outlined,
                        size: 56,
                        color: Palette.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Verificar código',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa el código de 6 dígitos enviado a\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, _buildCodeBox),
                      ),
                      const SizedBox(height: 20),
                      if (!expired)
                        Text(
                          'El código expira en ${_formatTime(_countdown)}',
                          style: TextStyle(
                            color:
                                _countdown <= 60
                                    ? Colors.orange
                                    : Colors.black54,
                            fontSize: 13,
                          ),
                        )
                      else
                        const Text(
                          'El código ha expirado',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (!expired)
                        AppButton(
                          label: 'VERIFICAR',
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _verify,
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed:
                            (_canResend && !_isLoading) ? _resendCode : null,
                        child: Text(
                          _canResend
                              ? 'Reenviar código'
                              : 'Reenviar en ${_resendCooldown}s',
                          style: TextStyle(
                            color: _canResend ? Palette.primary : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}
