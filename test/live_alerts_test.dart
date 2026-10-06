import 'dart:convert';

import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/design/design.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/presentation/live_trip_screen.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/trip_events_card.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:drivesense/features/telemetria/data/event_alert_service.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/live_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _inicio = DateTime(2026, 10, 4, 12);

DateTime _en(int segundos) => _inicio.add(Duration(seconds: segundos));

EventoRiesgo _evento(
  TipoEvento tipo,
  int segundo, {
  double? duracionS,
  bool enCurso = false,
}) => EventoRiesgo(
  tipo: tipo,
  fecha: _en(segundo),
  intensidad: 4,
  latitud: -17.78,
  longitud: -63.18,
  velocidadPreviaMs: 18,
  velocidadMaximaMs: tipo == TipoEvento.excesoVelocidad ? 18 : null,
  duracionS: duracionS,
  enCurso: enCurso,
);

ViajeActivo _viaje([List<EventoRiesgo> eventos = const []]) => ViajeActivo(
  recorridoId: 1,
  fechaInicioServidor: _inicio,
  acumulador: AcumuladorRecorrido(inicio: _inicio),
  eventos: [...eventos],
);

ViajeEnCurso _estado(
  ViajeActivo viaje, {
  required int ahora,
  EventoRiesgo? puntual,
  int? puntualDesde,
}) => ViajeEnCurso(
  viaje: viaje,
  ahora: _en(ahora),
  avisoPuntual: puntual,
  avisoPuntualDesde: puntualDesde == null ? null : _en(puntualDesde),
);

Future<void> _mostrar(WidgetTester tester, Widget widget) => tester.pumpWidget(
  MaterialApp(
    theme: temaClaro(),
    home: Scaffold(body: SingleChildScrollView(child: widget)),
  ),
);

Future<void> _bloque(WidgetTester tester, ViajeEnCurso estado) async {
  await _mostrar(tester, BloqueVelocidadEnVivo(viaje: estado, alVolver: () {}));
  // Deja terminar el cambio animado de cápsula
  await tester.pumpAndSettle();
}

/// Color del número de velocidad (sin lecturas, "0").
Color? _colorVelocidad(WidgetTester tester) =>
    tester.widget<Text>(find.text('0')).style?.color;

ColoresDriveSense get _colores => ColoresDriveSense.claro;

class _AvisosFalso implements AvisosEvento {
  final avisos = <bool>[];

  @override
  Future<void> avisar({required bool sonido}) async => avisos.add(sonido);
}

void main() {
  group('Aviso de evento puntual', () {
    final giro = _evento(TipoEvento.giroAgresivo, 10);

    testWidgets('aparece en lugar de la máxima y se va a los 4 s', (
      tester,
    ) async {
      final viaje = _viaje([giro]);
      await _bloque(
        tester,
        _estado(viaje, ahora: 11, puntual: giro, puntualDesde: 10),
      );
      expect(find.text('Giro agresivo'), findsOneWidget);
      expect(find.byIcon(Icons.turn_right), findsOneWidget);
      expect(find.textContaining('Máxima'), findsNothing);

      await _bloque(
        tester,
        _estado(viaje, ahora: 14, puntual: giro, puntualDesde: 10),
      );
      expect(find.text('Giro agresivo'), findsNothing);
      expect(find.textContaining('Máxima'), findsOneWidget);
    });
  });

  group('Aviso de exceso de velocidad', () {
    testWidgets('muestra el tiempo sobre el límite y desaparece al cerrarse', (
      tester,
    ) async {
      final abierto = _evento(
        TipoEvento.excesoVelocidad,
        0,
        duracionS: 12,
        enCurso: true,
      );
      await _bloque(tester, _estado(_viaje([abierto]), ahora: 13));
      expect(find.text('Sobre el límite de 60'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      expect(find.textContaining('Máxima'), findsNothing);
      expect(_colorVelocidad(tester), _colores.eventoVelocidad);

      // Sigue el tramo: el tiempo avanza
      final mas = abierto.copyWith(duracionS: 75);
      await _bloque(tester, _estado(_viaje([mas]), ahora: 76));
      expect(find.text('1:15'), findsOneWidget);

      // Bajó del límite: el evento se cerró
      await _bloque(tester, _estado(_viaje([mas.cerrado()]), ahora: 78));
      expect(find.text('Sobre el límite de 60'), findsNothing);
      expect(find.textContaining('Máxima'), findsOneWidget);
      expect(_colorVelocidad(tester), _colores.encabezadoTexto);
    });
  });

  group('Prioridad', () {
    testWidgets('un evento puntual tapa al exceso mientras se muestra', (
      tester,
    ) async {
      final exceso = _evento(
        TipoEvento.excesoVelocidad,
        0,
        duracionS: 20,
        enCurso: true,
      );
      final frenada = _evento(TipoEvento.frenadaBrusca, 20);
      final viaje = _viaje([exceso, frenada]);

      await _bloque(
        tester,
        _estado(viaje, ahora: 21, puntual: frenada, puntualDesde: 20),
      );
      expect(find.text('Frenada brusca'), findsOneWidget);
      expect(find.text('Sobre el límite de 60'), findsNothing);
      expect(_colorVelocidad(tester), _colores.encabezadoTexto);

      // Pasados los 4 s vuelve el exceso, que sigue abierto
      await _bloque(
        tester,
        _estado(viaje, ahora: 24, puntual: frenada, puntualDesde: 20),
      );
      expect(find.text('Frenada brusca'), findsNothing);
      expect(find.text('Sobre el límite de 60'), findsOneWidget);
      expect(_colorVelocidad(tester), _colores.eventoVelocidad);
    });
  });

  group('GestorAvisos', () {
    test('dos eventos puntuales seguidos: queda el último y su plazo se '
        'reinicia', () {
      final gestor = GestorAvisos();
      final frenada = _evento(TipoEvento.frenadaBrusca, 0);
      final giro = _evento(TipoEvento.giroAgresivo, 2);
      gestor.registrar(frenada, nuevo: true, ahora: _en(0));
      gestor.registrar(giro, nuevo: true, ahora: _en(2));

      AvisoEnVivo aviso(int segundo) => AvisoEnVivo.de(
        eventos: [frenada, giro],
        ahora: _en(segundo),
        puntual: gestor.puntual,
        puntualDesde: gestor.puntualDesde,
      );
      // A los 5 s de la frenada sigue el giro (2 + 4 = 6)
      expect((aviso(5) as AvisoPuntual).tipo, TipoEvento.giroAgresivo);
      expect(aviso(6), isA<SinAviso>());
    });

    test('avisan los eventos nuevos, no las actualizaciones ni el cierre del '
        'exceso', () {
      final gestor = GestorAvisos();
      final exceso = _evento(
        TipoEvento.excesoVelocidad,
        0,
        duracionS: 5,
        enCurso: true,
      );
      expect(gestor.registrar(exceso, nuevo: true, ahora: _en(5)), isTrue);
      // El exceso no ocupa el aviso puntual
      expect(gestor.puntual, isNull);
      expect(
        gestor.registrar(
          exceso.copyWith(duracionS: 6),
          nuevo: false,
          ahora: _en(6),
        ),
        isFalse,
      );
      expect(
        gestor.registrar(exceso.cerrado(), nuevo: false, ahora: _en(7)),
        isFalse,
      );
      expect(
        gestor.registrar(
          _evento(TipoEvento.aceleracionSevera, 8),
          nuevo: true,
          ahora: _en(8),
        ),
        isTrue,
      );
    });

    test('con el sonido silenciado solo vibra; las actualizaciones no '
        'avisan', () {
      final viaje = _viaje();
      final gestor = GestorAvisos();
      final servicio = _AvisosFalso();
      final exceso = _evento(
        TipoEvento.excesoVelocidad,
        0,
        duracionS: 5,
        enCurso: true,
      );
      void registrar(EventoRiesgo e, {required bool sonido}) =>
          registrarYAvisar(
            viaje,
            e,
            avisos: gestor,
            servicio: servicio,
            sonido: sonido,
            ahora: _en(0),
          );

      registrar(exceso, sonido: false);
      registrar(exceso.copyWith(duracionS: 6), sonido: false);
      registrar(_evento(TipoEvento.giroAgresivo, 9), sonido: true);
      expect(servicio.avisos, [false, true]);
      expect(viaje.eventos, hasLength(2));
    });
  });

  group('Tarjeta de eventos del viaje', () {
    Color? colorDe(WidgetTester tester, TipoEvento tipo) {
      final contador = find.byWidgetPredicate(
        (w) => w is ContadorEvento && w.tipo == tipo,
      );
      final caja = tester.widget<Container>(
        find.descendant(of: contador, matching: find.byType(Container)).first,
      );
      return (caja.decoration as BoxDecoration?)?.color;
    }

    /// El número que se ve en el contador de [tipo].
    String cantidadDe(WidgetTester tester, TipoEvento tipo) {
      final textos = tester.widgetList<Text>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ContadorEvento && w.tipo == tipo,
          ),
          matching: find.byType(Text),
        ),
      );
      return textos.first.data!;
    }

    testWidgets('cuenta cada tipo; un exceso actualizado cuenta una vez y el '
        '0 se ve en gris', (tester) async {
      final viaje = _viaje();
      final exceso = _evento(
        TipoEvento.excesoVelocidad,
        30,
        duracionS: 5,
        enCurso: true,
      );
      for (final e in [
        _evento(TipoEvento.frenadaBrusca, 1),
        _evento(TipoEvento.frenadaBrusca, 20),
        _evento(TipoEvento.giroAgresivo, 25),
        exceso,
        exceso.copyWith(duracionS: 9),
        exceso.copyWith(duracionS: 12).cerrado(),
      ]) {
        viaje.registrarEvento(e);
      }
      await _mostrar(tester, TarjetaEventosViaje(eventos: viaje.eventos));

      expect(find.text('Eventos de este viaje'.toUpperCase()), findsOneWidget);
      expect(cantidadDe(tester, TipoEvento.frenadaBrusca), '2');
      expect(cantidadDe(tester, TipoEvento.aceleracionSevera), '0');
      expect(cantidadDe(tester, TipoEvento.giroAgresivo), '1');
      expect(cantidadDe(tester, TipoEvento.excesoVelocidad), '1');

      expect(
        colorDe(tester, TipoEvento.frenadaBrusca),
        _colores.tinteEventoFrenada,
      );
      expect(
        colorDe(tester, TipoEvento.aceleracionSevera),
        _colores.superficieAlt,
      );
      final numeroCero = tester.widget<Text>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is ContadorEvento && w.tipo == TipoEvento.aceleracionSevera,
          ),
          matching: find.text('0'),
        ),
      );
      expect(numeroCero.style?.color, _colores.textoSecundario);
    });

    testWidgets('un viaje continuado incluye los eventos de antes', (
      tester,
    ) async {
      // Guardado en el teléfono antes de que la app se cerrara
      final guardado = _viaje([
        _evento(TipoEvento.frenadaBrusca, 1),
        _evento(TipoEvento.giroAgresivo, 5),
      ]).toJson();
      // Mismo camino que el almacenamiento: JSON de ida y vuelta
      final continuado = ViajeActivo.fromJson(
        jsonDecode(jsonEncode(guardado)) as Map<String, dynamic>,
      );
      continuado.registrarEvento(_evento(TipoEvento.frenadaBrusca, 60));
      await _mostrar(tester, TarjetaEventosViaje(eventos: continuado.eventos));

      expect(cantidadDe(tester, TipoEvento.frenadaBrusca), '2');
      expect(cantidadDe(tester, TipoEvento.giroAgresivo), '1');
    });
  });
}
