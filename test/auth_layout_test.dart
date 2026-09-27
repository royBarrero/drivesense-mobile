import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/design/design.dart';
import 'package:drivesense/features/auth/presentation/login_screen.dart';
import 'package:drivesense/features/auth/presentation/register_screen.dart';
import 'package:drivesense/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Como el A34: 1080×2340 px, densidad 2.625 y barra de estado de ~27 dp
  const dpr = 2.625;
  const barraEstado = 27.0;

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = const FakeViewPadding(top: barraEstado * dpr);
    tester.view.viewPadding = const FakeViewPadding(top: barraEstado * dpr);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: temaClaro(), home: pantalla),
      ),
    );
  }

  /// Alto visible del bloque oscuro: franja de la barra de estado + encabezado.
  double altoBloqueOscuro(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(EncabezadoAuth)).dy;

  for (final (nombre, pantalla) in [
    ('login', const LoginPantalla()),
    ('registro', const RegistroPantalla()),
  ]) {
    testWidgets('$nombre: el contenido nunca pasa bajo la barra de estado', (
      tester,
    ) async {
      await abrir(tester, pantalla);

      // Franja fija del color del encabezado sobre la barra de estado
      final franja = find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == ColoresDriveSense.claro.encabezadoFondo,
      );
      expect(tester.getSize(franja.first).height, barraEstado);

      // El scroll empieza debajo de la barra, también después de desplazar
      final scroll = find.byType(SingleChildScrollView);
      expect(tester.getTopLeft(scroll).dy, barraEstado);
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pump();
      expect(tester.getTopLeft(scroll).dy, barraEstado);
      expect(tester.getSize(franja.first).height, barraEstado);
    });
  }

  testWidgets('login: el bloque oscuro mide 392 (barra incluida)', (
    tester,
  ) async {
    await abrir(tester, const LoginPantalla());
    expect(altoBloqueOscuro(tester), Medidas.altoEncabezadoLogin);
  });

  testWidgets('registro: el bloque oscuro mide al menos 240 (barra incluida)', (
    tester,
  ) async {
    await abrir(tester, const RegistroPantalla());
    expect(
      altoBloqueOscuro(tester),
      greaterThanOrEqualTo(Medidas.altoMinimoEncabezadoRegistro),
    );
  });
}
