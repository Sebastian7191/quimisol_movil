import 'package:flutter/services.dart';

/// Validación del nombre de una persona (registro y perfiles).
///
/// Acepta letras (incluye tildes, ñ y ü), espacios, apóstrofo, punto y guion
/// ("María José", "O'Connor", "Ana-Lucía"). No acepta números ni otros
/// símbolos.
class NombreValidator {
  const NombreValidator._();

  static final RegExp _digitos = RegExp(r'\d');
  static final RegExp _permitidos = RegExp(r"^[\p{L}\s'.\-]+$", unicode: true);
  static final RegExp _letra = RegExp(r'\p{L}', unicode: true);

  /// Para `TextFormField.validator`.
  static String? validar(String? value) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return 'Ingresa tu nombre';
    if (_digitos.hasMatch(s)) return 'El nombre no puede tener números';
    if (!_permitidos.hasMatch(s)) return 'El nombre solo puede tener letras';
    if (_letra.allMatches(s).length < 2) return 'El nombre es muy corto';
    return null;
  }

  /// Impide escribir o pegar números en el campo.
  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.deny(_digitos),
  ];
}
