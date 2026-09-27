import 'package:drivesense/features/auth/models/register_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nombre', () {
    expect(validarNombre('Ana'), isNull);
    expect(validarNombre('   '), 'Ingresa tu nombre');
  });

  test('correo', () {
    expect(validarCorreo('ana@prueba.bo'), isNull);
    expect(
      validarCorreo('  Ana@Prueba.bo '),
      isNull,
      reason: 'se recorta al enviar',
    );
    expect(validarCorreo('ana@prueba'), 'Ingresa un correo válido');
    expect(validarCorreo('ana prueba@x.bo'), 'Ingresa un correo válido');
    expect(validarCorreo(''), 'Ingresa un correo válido');
  });

  test('teléfono', () {
    expect(validarTelefono('71234567'), isNull);
    expect(validarTelefono('7123456'), 'El teléfono debe tener 8 dígitos');
    expect(validarTelefono('712345678'), 'El teléfono debe tener 8 dígitos');
    expect(validarTelefono('7123456a'), 'El teléfono debe tener 8 dígitos');
  });

  test('requisitos de la contraseña', () {
    final vacia = RequisitosContrasenia('');
    expect(
      [vacia.largo, vacia.letra, vacia.numero, vacia.cumple],
      [false, false, false, false],
    );

    final soloLetras = RequisitosContrasenia('abcdefgh');
    expect(
      [soloLetras.largo, soloLetras.letra, soloLetras.numero],
      [true, true, false],
    );

    final corta = RequisitosContrasenia('ab1');
    expect([corta.largo, corta.letra, corta.numero], [false, true, true]);

    // Como en el backend, una letra con tilde no cuenta como letra
    expect(RequisitosContrasenia('ñññññ123').letra, isFalse);

    expect(RequisitosContrasenia('clave1234').cumple, isTrue);
  });

  test('confirmación', () {
    expect(validarConfirmacion('clave1234', 'clave1234'), isNull);
    expect(validarConfirmacion('clave1234', ''), 'Confirma tu contraseña');
    expect(
      validarConfirmacion('clave1234', 'clave123'),
      'Las contraseñas no coinciden',
    );
  });
}
