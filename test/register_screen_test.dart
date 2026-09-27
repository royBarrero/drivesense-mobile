import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> abrirRegistro(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: temaClaro(), home: const RegistroPantalla()),
      ),
    );
  }

  // Orden de los campos: nombre, correo, teléfono, contraseña, confirmación
  Finder campo(int i) => find.byType(TextField).at(i);

  FilledButton boton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  Color colorRequisito(WidgetTester tester, String texto) =>
      tester.widget<Text>(find.text(texto)).style!.color!;

  testWidgets('El botón se habilita solo con todo el formulario válido', (
    tester,
  ) async {
    await abrirRegistro(tester);
    expect(boton(tester).onPressed, isNull);

    await tester.enterText(campo(0), 'Ana Prueba');
    await tester.enterText(campo(1), 'ana@prueba.bo');
    await tester.enterText(campo(2), '71234567');
    await tester.enterText(campo(3), 'clave1234');
    await tester.pump();
    expect(boton(tester).onPressed, isNull, reason: 'falta la confirmación');

    await tester.enterText(campo(4), 'clave1234');
    await tester.pump();
    expect(boton(tester).onPressed, isNotNull);
  });

  testWidgets('Los requisitos de la contraseña se marcan al cumplirse', (
    tester,
  ) async {
    await abrirRegistro(tester);
    final pendiente = colorRequisito(tester, 'Al menos un número');

    await tester.enterText(campo(3), 'abc');
    await tester.pump();
    final cumplido = colorRequisito(tester, 'Al menos una letra');
    expect(cumplido, isNot(pendiente));
    expect(colorRequisito(tester, 'Al menos 8 caracteres'), pendiente);
    expect(colorRequisito(tester, 'Al menos un número'), pendiente);

    await tester.enterText(campo(3), 'abcdefg1');
    await tester.pump();
    expect(colorRequisito(tester, 'Al menos 8 caracteres'), cumplido);
    expect(colorRequisito(tester, 'Al menos un número'), cumplido);
  });

  testWidgets(
    '"Las contraseñas no coinciden" aparece solo al salir del campo',
    (tester) async {
      await abrirRegistro(tester);
      const mensaje = 'Las contraseñas no coinciden';

      await tester.enterText(campo(3), 'clave1234');
      await tester.enterText(campo(4), 'clave12');
      await tester.pump();
      expect(find.text(mensaje), findsNothing, reason: 'aún está escribiendo');

      // Salir del campo de confirmación
      await tester.tap(campo(0));
      await tester.pump();
      expect(find.text(mensaje), findsOneWidget);

      // Corregirlo actualiza el error al momento
      await tester.enterText(campo(4), 'clave1234');
      await tester.pump();
      expect(find.text(mensaje), findsNothing);
    },
  );

  testWidgets('El teléfono solo acepta 8 dígitos', (tester) async {
    await abrirRegistro(tester);
    await tester.enterText(campo(2), '7a1b2c3456789');
    await tester.pump();
    expect(tester.widget<TextField>(campo(2)).controller!.text, '71234567');
    expect(find.text('8 dígitos, sin código de país'), findsOneWidget);
  });
}
