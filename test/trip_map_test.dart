import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/recorridos/models/route_simplifier.dart';
import 'package:drivesense/features/recorridos/presentation/trip_format.dart';
import 'package:drivesense/features/recorridos/presentation/trip_map_screen.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/trip_map.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _hoy = DateTime.now();
final _inicio = DateTime(_hoy.year, _hoy.month, _hoy.day, 16, 5);

/// ~111 m por cada 0,001° de latitud.
PuntoRuta _punto(double lat, double lon, [int segundo = 0]) => PuntoRuta(
  latitud: lat,
  longitud: lon,
  fecha: _inicio.add(Duration(seconds: segundo)),
  velocidadKmh: 30,
);

EventoRiesgo _evento(
  TipoEvento tipo,
  int minuto, {
  double intensidad = 3.4,
  double velocidadKmh = 38,
  double? maximaKmh,
  double? duracionS,
}) => EventoRiesgo(
  tipo: tipo,
  fecha: _inicio.add(Duration(minutes: minuto)),
  intensidad: intensidad,
  latitud: -17.78 + minuto * 0.0005,
  longitud: -63.18,
  velocidadPreviaMs: velocidadKmh / 3.6,
  velocidadMaximaMs: maximaKmh == null ? null : maximaKmh / 3.6,
  duracionS: duracionS,
);

final _frenada = _evento(TipoEvento.frenadaBrusca, 2);
final _aceleracion = _evento(
  TipoEvento.aceleracionSevera,
  4,
  intensidad: 2.8,
  velocidadKmh: 10,
);
final _giro = _evento(
  TipoEvento.giroAgresivo,
  7,
  intensidad: 3.9,
  velocidadKmh: 29,
);
final _exceso = _evento(
  TipoEvento.excesoVelocidad,
  10,
  intensidad: 2.2,
  velocidadKmh: 61,
  maximaKmh: 68,
  duracionS: 9.4,
);
final _otraFrenada = _evento(TipoEvento.frenadaBrusca, 14);

void main() {
  group('Simplificación de la ruta', () {
    test('una recta queda en sus dos extremos', () {
      final recta = [
        for (var i = 0; i < 50; i++) _punto(-17.78 + i * 0.0001, -63.18, i),
      ];
      final simple = simplificarRuta(recta);
      expect(simple, [recta.first, recta.last]);
    });

    test('conserva las esquinas', () {
      final ruta = [
        for (var i = 0; i <= 10; i++) _punto(-17.78 + i * 0.0001, -63.18, i),
        for (var i = 1; i <= 10; i++)
          _punto(-17.779, -63.18 + i * 0.0001, 10 + i),
      ];
      final simple = simplificarRuta(ruta);
      expect(simple, [ruta.first, ruta[10], ruta.last]);
    });

    test('un desvío menor que la tolerancia se descarta; uno mayor, no', () {
      // 0,00003° ≈ 3,3 m; 0,0001° ≈ 11 m
      final chico = [
        _punto(-17.78, -63.18),
        _punto(-17.7795, -63.18003, 1),
        _punto(-17.779, -63.18, 2),
      ];
      expect(simplificarRuta(chico), hasLength(2));
      final grande = [chico[0], _punto(-17.7795, -63.1801, 1), chico[2]];
      expect(simplificarRuta(grande), hasLength(3));
    });

    test('con menos de 3 puntos o una vuelta al mismo lugar', () {
      expect(simplificarRuta([_punto(-17.78, -63.18)]), hasLength(1));
      final vuelta = [
        _punto(-17.78, -63.18),
        _punto(-17.779, -63.18, 1),
        _punto(-17.78, -63.18, 2),
      ];
      expect(simplificarRuta(vuelta), vuelta);
    });

    test('10 000 puntos en zigzag sin desbordar la pila', () {
      final ruta = [
        for (var i = 0; i < 10000; i++)
          _punto(-17.78 + i * 0.0001, -63.18 + (i.isEven ? 0 : 0.0002), i),
      ];
      final simple = simplificarRuta(ruta);
      expect(simple.first, ruta.first);
      expect(simple.last, ruta.last);
    });
  });

  group('Texto de los eventos', () {
    test('lo medido y la velocidad de cada tipo', () {
      expect(FormatoEvento.detalle(_frenada), '3,4 m/s² · a 38 km/h');
      expect(FormatoEvento.detalle(_aceleracion), '2,8 m/s² · desde 10 km/h');
      expect(FormatoEvento.detalle(_giro), '3,9 m/s² · a 29 km/h');
      expect(FormatoEvento.detalle(_exceso), '9 s · máx. 68 km/h');
    });

    test('un exceso de un minuto o más va en m:ss', () {
      final largo = _evento(
        TipoEvento.excesoVelocidad,
        10,
        maximaKmh: 72,
        duracionS: 75,
      );
      expect(FormatoEvento.detalle(largo), '1:15 · máx. 72 km/h');
    });
  });

  group('Mapa completo', () {
    Future<void> mostrar(
      WidgetTester tester, {
      List<EventoRiesgo>? eventos,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(),
          home: MapaViajePantalla(
            datos: DatosMapaViaje(
              ruta: [
                for (var i = 0; i < 20; i++)
                  _punto(-17.78 + i * 0.0005, -63.18 + (i % 3) * 0.0003, i),
              ],
              eventos:
                  eventos ??
                  [_frenada, _aceleracion, _giro, _exceso, _otraFrenada],
              llegada: _inicio.add(const Duration(minutes: 18)),
              duracionS: 18 * 60,
              distanciaM: 7400,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Filas de la lista (cada evento muestra su hora).
    Finder fila(String hora) =>
        find.ancestor(of: find.text(hora), matching: find.byType(InkWell));

    testWidgets('título, filtros con su cantidad y la lista', (tester) async {
      await mostrar(tester);
      expect(find.text('Ruta del viaje'), findsOneWidget);
      expect(find.text('Hoy · 16:05 – 16:23 · 7,40 km'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Eventos del viaje'), findsOneWidget);
      // La segunda frenada queda bajo el borde de la hoja
      expect(find.text('Frenada brusca'), findsWidgets);
      expect(find.text('16:07'), findsOneWidget);
      expect(find.text('2,8 m/s² · desde 10 km/h'), findsOneWidget);
      // Atribución siempre visible
      expect(find.text('© OpenStreetMap'), findsOneWidget);
    });

    testWidgets('el filtro deja solo los eventos de ese tipo', (tester) async {
      await mostrar(tester);
      await tester.tap(find.text('Frenadas'));
      await tester.pumpAndSettle();
      expect(find.text('Frenada brusca'), findsNWidgets(2));
      expect(find.text('Giro agresivo'), findsNothing);
      expect(find.text('Aceleración severa'), findsNothing);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Giro agresivo'), findsOneWidget);
    });

    testWidgets('tocar un evento muestra su detalle sobre el mapa', (
      tester,
    ) async {
      await mostrar(tester);
      expect(find.byType(BurbujaEvento), findsNothing);

      await tester.ensureVisible(fila('16:12'));
      await tester.pumpAndSettle();
      await tester.tap(fila('16:12'));
      await tester.pumpAndSettle();
      final burbuja = find.byType(BurbujaEvento);
      expect(burbuja, findsOneWidget);
      expect(
        find.descendant(of: burbuja, matching: find.text('Giro agresivo')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: burbuja,
          matching: find.text('3,9 m/s² · a 29 km/h'),
        ),
        findsOneWidget,
      );

      // Un filtro que lo oculta lo deselecciona
      await tester.tap(find.text('Frenadas'));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaEvento), findsNothing);
    });

    testWidgets('ver la ruta entera quita la selección', (tester) async {
      await mostrar(tester);
      await tester.tap(fila('16:07'));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaEvento), findsOneWidget);

      await tester.tap(find.byTooltip('Ver la ruta entera'));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaEvento), findsNothing);
    });

    testWidgets('sin eventos: mensaje y sin filtros', (tester) async {
      await mostrar(tester, eventos: []);
      expect(
        find.text('Sin eventos de riesgo en este viaje. ¡Sigue así!'),
        findsOneWidget,
      );
      expect(find.text('Todos'), findsNothing);
    });
  });
}
