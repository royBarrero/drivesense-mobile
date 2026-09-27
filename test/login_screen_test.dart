import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('El botón de login se habilita solo con ambos campos llenos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: temaClaro(), home: const LoginPantalla()),
      ),
    );

    FilledButton boton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    const ayuda = 'Completa ambos campos para continuar';

    expect(boton().onPressed, isNull);
    expect(find.text(ayuda), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'ana@prueba.com');
    await tester.pump();
    expect(boton().onPressed, isNull, reason: 'falta la contraseña');

    await tester.enterText(find.byType(TextField).at(1), 'clave1234');
    await tester.pump();
    expect(boton().onPressed, isNotNull);
    expect(find.text(ayuda), findsNothing);
  });
}
