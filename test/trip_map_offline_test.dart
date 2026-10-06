import 'dart:io';

import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/trip_map.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aparte de `trip_map_test.dart`: la caché de mosaicos de flutter_map es una
/// sola para todo el proceso y queda atada al reloj falso de la primera prueba
/// que la usa; cada archivo de pruebas corre en su propio proceso.

final _inicio = DateTime(2026, 10, 4, 16, 5);

PuntoRuta _punto(double lat, double lon, [int segundo = 0]) => PuntoRuta(
  latitud: lat,
  longitud: lon,
  fecha: _inicio.add(Duration(seconds: segundo)),
  velocidadKmh: 30,
);

final _frenada = EventoRiesgo(
  tipo: TipoEvento.frenadaBrusca,
  fecha: _inicio.add(const Duration(minutes: 2)),
  intensidad: 3.4,
  latitud: -17.775,
  longitud: -63.175,
  velocidadPreviaMs: 10,
);

void main() {
  // La caché de mosaicos de flutter_map (una sola para toda la app) pide su
  // carpeta a path_provider
  TestWidgetsFlutterBinding.ensureInitialized();
  final carpeta = Directory.systemTemp.createTempSync('mosaicos');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => carpeta.path,
      );
  tearDownAll(() {
    try {
      carpeta.deleteSync(recursive: true);
    } on FileSystemException {
      // En Windows la caché puede seguir con el archivo abierto; queda en la
      // carpeta temporal del sistema
    }
  });

  testWidgets('sin internet: aviso en lugar del mapa', (tester) async {
    // En las pruebas toda petición HTTP responde 400: los mosaicos fallan
    bool? disponible;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: MapaViaje(
              ruta: [_punto(-17.78, -63.18), _punto(-17.77, -63.17, 60)],
              eventos: [_frenada],
              alCambiarDisponibilidad: (valor) => disponible = valor,
            ),
          ),
        ),
      ),
    );
    // Las descargas y la decodificación corren fuera del reloj falso
    for (
      var i = 0;
      i < 20 && find.text('Sin conexión').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(disponible, isFalse);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(disponible, isTrue);
    expect(find.text('Sin conexión'), findsNothing);
  });
}
