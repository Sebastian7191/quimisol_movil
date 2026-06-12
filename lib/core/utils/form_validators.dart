// Validadores reutilizables para formularios de autenticación
// (login, registro y cambio de contraseña).
//
// Objetivo: validaciones "profesionales" pero claras:
//   - Correo: estructura RFC práctica, sin espacios, sin emojis ni
//     caracteres no permitidos, con límites de longitud y dominio válido.
//   - Contraseña: complejidad mínima real (mayúscula, minúscula, dígito y
//     carácter especial), sin espacios ni emojis.
//
// Además se exponen `inputFormatters` que impiden escribir/pegar emojis
// (y espacios) directamente en los campos, como primera línea de defensa.

import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Conjuntos de caracteres permitidos
// ---------------------------------------------------------------------------

// Caracteres válidos en un correo electrónico (local + dominio).
// Bloquea espacios, emojis y cualquier símbolo fuera de este conjunto.
final RegExp _emailAllowedChars = RegExp(r'^[A-Za-z0-9@._%+\-]+$');

// Caracteres permitidos en contraseña: ASCII visible (del '!' al '~').
// Esto excluye espacios, emojis, tildes y cualquier carácter de control.
final RegExp _passwordAllowedChars = RegExp(r'^[\x21-\x7E]+$');

// Componentes de complejidad de la contraseña.
final RegExp _hasUppercase = RegExp(r'[A-Z]');
final RegExp _hasLowercase = RegExp(r'[a-z]');
final RegExp _hasDigit = RegExp(r'[0-9]');
final RegExp _hasSpecial = RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\];'/\\`~]''');

// Estructura general del correo (validación final tras los chequeos por partes).
final RegExp _emailRegex = RegExp(
  r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?"
  r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
);

// ---------------------------------------------------------------------------
// InputFormatters (bloquean entrada/pegado de caracteres no permitidos)
// ---------------------------------------------------------------------------

/// Para campos de correo: permite solo caracteres válidos de email.
/// Bloquea emojis y espacios al escribir o pegar.
final List<TextInputFormatter> emailInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
  LengthLimitingTextInputFormatter(254),
];

/// Para campos de contraseña: permite solo ASCII visible (sin espacios
/// ni emojis), aceptando letras, números y símbolos comunes.
final List<TextInputFormatter> passwordInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[\x21-\x7E]')),
  LengthLimitingTextInputFormatter(64),
];

// ---------------------------------------------------------------------------
// Validación de correo
// ---------------------------------------------------------------------------

String? validateEmail(String? value) {
  final v = (value ?? '').trim();

  if (v.isEmpty) return 'Ingresa tu correo';
  if (v.contains(' ')) return 'El correo no puede contener espacios';
  if (!_emailAllowedChars.hasMatch(v)) {
    return 'El correo contiene caracteres no permitidos (emojis o símbolos)';
  }
  if (v.length > 254) return 'El correo es demasiado largo';

  final atCount = '@'.allMatches(v).length;
  if (atCount == 0) return 'Falta el símbolo @ (ej. nombre@dominio.com)';
  if (atCount > 1) return 'El correo solo puede tener un símbolo @';

  final parts = v.split('@');
  final local = parts[0];
  final domain = parts[1];

  if (local.isEmpty) return 'Falta la parte antes del @';
  if (local.length > 64) return 'La parte antes del @ es demasiado larga';
  if (local.startsWith('.') || local.endsWith('.')) {
    return 'El correo no puede empezar o terminar con un punto';
  }
  if (local.contains('..')) return 'El correo no puede tener puntos seguidos';

  if (domain.isEmpty) return 'Falta el dominio después del @';
  if (!domain.contains('.')) return 'El dominio debe incluir un punto (ej. .com)';
  if (domain.startsWith('.') ||
      domain.endsWith('.') ||
      domain.startsWith('-') ||
      domain.endsWith('-')) {
    return 'El dominio del correo no es válido';
  }
  if (domain.contains('..')) return 'El dominio no puede tener puntos seguidos';

  if (!_emailRegex.hasMatch(v)) {
    return 'Ingresa un correo válido (ej. nombre@dominio.com)';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Validación de contraseña
// ---------------------------------------------------------------------------

/// Para iniciar sesión: no exigimos reglas de complejidad (cuentas ya
/// existentes pudieron crearse con otras reglas), pero sí rechazamos
/// espacios y emojis para evitar entradas inválidas.
String? validateLoginPassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Ingresa tu contraseña';
  if (v.contains(' ')) return 'La contraseña no puede contener espacios';
  if (!_passwordAllowedChars.hasMatch(v)) {
    return 'La contraseña no puede contener emojis ni espacios';
  }
  return null;
}

/// Texto de ayuda que describe los requisitos de la contraseña.
const String passwordRequirementsHint =
    'Mínimo 8 caracteres, con mayúscula, minúscula, número y un símbolo.';

/// Para registro y cambio de contraseña: complejidad mínima real.
String? validateNewPassword(String? value) {
  final v = value ?? '';

  if (v.isEmpty) return 'Ingresa una contraseña';
  if (v.contains(' ')) return 'La contraseña no puede contener espacios';
  if (!_passwordAllowedChars.hasMatch(v)) {
    return 'La contraseña no puede contener emojis ni espacios';
  }
  if (v.length < 8) return 'Debe tener al menos 8 caracteres';
  if (v.length > 64) return 'No puede superar los 64 caracteres';
  if (!_hasUppercase.hasMatch(v)) return 'Debe incluir al menos una mayúscula';
  if (!_hasLowercase.hasMatch(v)) return 'Debe incluir al menos una minúscula';
  if (!_hasDigit.hasMatch(v)) return 'Debe incluir al menos un número';
  if (!_hasSpecial.hasMatch(v)) {
    return 'Debe incluir al menos un símbolo (ej. !@#\$%&*)';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String original) {
  if (value == null || value.isEmpty) return 'Confirma tu contraseña';
  if (value != original) return 'Las contraseñas no coinciden';
  return null;
}
