import 'package:flutter/services.dart';

import 'package:flutter/services.dart';

class DateTextInputFormatter extends TextInputFormatter {
  bool _esBisiesto(int anio) {
    return (anio % 4 == 0 && anio % 100 != 0) || (anio % 400 == 0);
  }

  int _diasEnMes(int mes, int anio) {
    switch (mes) {
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        return _esBisiesto(anio) ? 29 : 28;
      default:
        return 31;
    }
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    String mm = '';
    String dd = '';
    String yyyy = '';

    if (digits.length >= 1) {
      mm = digits.substring(0, digits.length >= 2 ? 2 : 1);
    }
    if (digits.length >= 3) {
      dd = digits.substring(2, digits.length >= 4 ? 4 : digits.length);
    }
    if (digits.length >= 5) {
      yyyy = digits.substring(4, digits.length > 8 ? 8 : digits.length);
    }

    // Validar mes parcial/final
    if (mm.isNotEmpty) {
      final mes = int.tryParse(mm);
      if (mes == null) return oldValue;

      if (mm.length == 1) {
        if (mes < 0 || mes > 1) return oldValue;
      } else {
        if (mes < 1 || mes > 12) return oldValue;
      }
    }

    // Validar año no mayor al actual cuando esté completo
    final anioActual = DateTime.now().year;
    int anioParaCalculo = anioActual;

    if (yyyy.isNotEmpty) {
      final anio = int.tryParse(yyyy);
      if (anio == null) return oldValue;

      if (yyyy.length == 4) {
        if (anio < 1 || anio > anioActual) return oldValue;
        anioParaCalculo = anio;
      }
    }

    // Validar día según mes
    if (dd.isNotEmpty) {
      final dia = int.tryParse(dd);
      if (dia == null) return oldValue;

      if (dd.length == 1) {
        if (dia < 0 || dia > 3) return oldValue;
      } else {
        final mes = (mm.length == 2) ? int.tryParse(mm) ?? 0 : 0;
        if (mes < 1 || mes > 12) return oldValue;

        final maxDias = _diasEnMes(mes, anioParaCalculo);
        if (dia < 1 || dia > maxDias) return oldValue;
      }
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}


class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    String hh = '';
    String mm = '';

    if (digits.length >= 1) {
      hh = digits.substring(0, digits.length >= 2 ? 2 : 1);
    }
    if (digits.length >= 3) {
      mm = digits.substring(2, digits.length > 4 ? 4 : digits.length);
    }

    // Validar horas
    if (hh.isNotEmpty) {
      final hora = int.tryParse(hh);
      if (hora == null) return oldValue;

      if (hh.length == 1) {
        if (hora < 0 || hora > 2) return oldValue;
      } else {
        if (hora < 0 || hora > 23) return oldValue;
      }
    }

    // Validar minutos
    if (mm.isNotEmpty) {
      final minuto = int.tryParse(mm);
      if (minuto == null) return oldValue;

      if (mm.length == 1) {
        if (minuto < 0 || minuto > 5) return oldValue;
      } else {
        if (minuto < 0 || minuto > 59) return oldValue;
      }
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 4; i++) {
      buffer.write(digits[i]);
      if (i == 1 && i != digits.length - 1) {
        buffer.write(':');
      }
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
