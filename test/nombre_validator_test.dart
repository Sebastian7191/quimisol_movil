import 'package:flutter_test/flutter_test.dart';
import 'package:quimisol_movil/shared/validators/nombre_validator.dart';

void main() {
  group('NombreValidator.validar', () {
    test('acepta nombres válidos', () {
      for (final nombre in [
        'Juan Pérez',
        'María José Ñuñez',
        "O'Connor",
        'Ana-Lucía Güemes',
        'Sr. Gómez',
      ]) {
        expect(NombreValidator.validar(nombre), isNull, reason: nombre);
      }
    });

    test('rechaza números', () {
      expect(
        NombreValidator.validar('Juan123'),
        'El nombre no puede tener números',
      );
      expect(
        NombreValidator.validar('4na'),
        'El nombre no puede tener números',
      );
    });

    test('rechaza vacío, símbolos y nombres muy cortos', () {
      expect(NombreValidator.validar('   '), 'Ingresa tu nombre');
      expect(NombreValidator.validar(null), 'Ingresa tu nombre');
      expect(
        NombreValidator.validar('juan@mail'),
        'El nombre solo puede tener letras',
      );
      expect(NombreValidator.validar('J'), 'El nombre es muy corto');
    });
  });
}
