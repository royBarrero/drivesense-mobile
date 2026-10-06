import 'dart:convert';

import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/models/trip_score.dart';
import 'package:drivesense/features/recorridos/presentation/trip_summary_screen.dart';
import 'package:drivesense/features/recorridos/providers/pending_summary_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _inicio = DateTime.utc(2026, 10, 4, 16, 5);

final _frenada = EventoRiesgo(
  tipo: TipoEvento.frenadaBrusca,
  fecha: _inicio.add(const Duration(minutes: 3)),
  intensidad: 3.2,
  latitud: -17.78,
  longitud: -63.18,
  velocidadPreviaMs: 10,
);

final _exceso = EventoRiesgo(
  tipo: TipoEvento.excesoVelocidad,
  fecha: _inicio.add(const Duration(minutes: 8)),
  intensidad: 2,
  latitud: -17.79,
  longitud: -63.19,
  velocidadPreviaMs: 17,
  velocidadMaximaMs: 20,
  duracionS: 12,
);

ResumenRecorrido _resumen({List<EventoRiesgo>? eventos}) => ResumenRecorrido(
  recorridoId: 7,
  fechaFin: _inicio.add(const Duration(minutes: 18)),
  distanciaM: 7400,
  duracionS: 1112,
  velocidadMaximaKmh: 62,
  velocidadPromedioKmh: 24,
  latitudFin: -17.8,
  longitudFin: -63.2,
  eventos: eventos,
);

PuntajeViaje _puntaje({
  int frenadas = 100,
  int aceleraciones = 100,
  int giros = 100,
  int velocidad = 100,
}) => PuntajeViaje(
  drivescore: 90,
  frenadas: frenadas,
  aceleraciones: aceleraciones,
  giros: giros,
  velocidad: velocidad,
);

const _puntaje86 = PuntajeViaje(
  drivescore: 86,
  frenadas: 70,
  aceleraciones: 100,
  giros: 76,
  velocidad: 100,
);

class _ViajeFijo extends ViajeNotifier {
  _ViajeFijo(this._estado);

  final EstadoViaje _estado;

  @override
  Future<EstadoViaje> build() async => _estado;
}

Future<ProviderContainer> _mostrarResumen(
  WidgetTester tester,
  ViajeTerminado estado,
) async {
  final contenedor = ProviderContainer(
    overrides: [viajeProvider.overrideWith(() => _ViajeFijo(estado))],
  );
  addTearDown(contenedor.dispose);
  // Pantalla de teléfono (~411 × 891): el desglose y las cifras a la vista
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp(
        theme: temaClaro(),
        home: const ResumenRecorridoPantalla(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return contenedor;
}

void main() {
  group('Envío de los eventos', () {
    test('van con velocidades en km/h; solo el exceso lleva duración y '
        'máxima', () {
      final eventos =
          _resumen(eventos: [_frenada, _exceso]).toApiJson()['eventos']
              as List<dynamic>;
      expect(eventos[0], {
        'tipo': 'frenada_brusca',
        'fecha': '2026-10-04T16:08:00.000Z',
        'lat': -17.78,
        'lon': -63.18,
        'velocidad_kmh': 36.0,
        'intensidad': 3.2,
      });
      final exceso = eventos[1] as Map<String, dynamic>;
      expect(exceso['tipo'], 'exceso_velocidad');
      expect(exceso['duracion_s'], 12);
      expect(exceso['velocidad_maxima_kmh'], closeTo(72, 1e-9));
    });

    test('el resumen toma los eventos del viaje', () {
      final viaje = ViajeActivo(
        recorridoId: 7,
        fechaInicioServidor: _inicio,
        acumulador: AcumuladorRecorrido(inicio: _inicio),
        eventos: [_frenada],
      );
      final resumen = ResumenRecorrido.desde(
        viaje,
        fechaFin: _inicio.add(const Duration(minutes: 18)),
        llegada: Lectura(
          latitud: 0,
          longitud: 0,
          precisionM: 5,
          velocidadMs: 0,
          fecha: _inicio,
        ),
      );
      expect(resumen.eventos?.single.tipo, TipoEvento.frenadaBrusca);
    });

    test('el resumen pendiente los conserva para el reintento', () {
      final guardado = jsonDecode(
        jsonEncode(_resumen(eventos: [_frenada, _exceso]).toJson()),
      );
      final leido = ResumenRecorrido.fromJson(guardado as Map<String, dynamic>);
      expect(leido.eventos, hasLength(2));
      final exceso = leido.eventos![1];
      expect(exceso.duracionS, 12);
      expect(exceso.velocidadMaximaMs, closeTo(20, 1e-9));
      expect(exceso.velocidadPreviaMs, closeTo(17, 1e-9));
      // Se reenvía igual que la primera vez
      expect(
        leido.toApiJson()['eventos'],
        _resumen(eventos: [_frenada, _exceso]).toApiJson()['eventos'],
      );
    });

    test('un pendiente de una versión anterior se envía sin eventos', () {
      final guardado = _resumen().toJson();
      final leido = ResumenRecorrido.fromJson(guardado);
      expect(leido.eventos, isNull);
      expect(leido.toApiJson().containsKey('eventos'), isFalse);
    });
  });

  group('Puntaje', () {
    test('se lee de la respuesta del backend', () {
      final json = {
        'id': 7,
        'estado': 'finalizado',
        'fecha_inicio': '2026-10-04T16:05:00Z',
        'drivescore': 86,
        'puntaje_frenadas': 70,
        'puntaje_aceleraciones': 100,
        'puntaje_giros': 76,
        'puntaje_velocidad': 100,
      };
      final puntaje = Recorrido.fromJson(json).puntaje!;
      expect(puntaje.drivescore, 86);
      expect(puntaje.giros, 76);
      expect(Recorrido.fromJson({...json, 'drivescore': null}).puntaje, isNull);
    });

    test('calificación en los bordes de cada rango', () {
      expect(Calificacion.de(100), Calificacion.excelente);
      expect(Calificacion.de(90), Calificacion.excelente);
      expect(Calificacion.de(89), Calificacion.muyBueno);
      expect(Calificacion.de(75), Calificacion.muyBueno);
      expect(Calificacion.de(74), Calificacion.regular);
      expect(Calificacion.de(60), Calificacion.regular);
      expect(Calificacion.de(59), Calificacion.riesgoso);
      expect(Calificacion.de(0), Calificacion.riesgoso);
    });
  });

  group('Lo que más restó (HU-16)', () {
    test('la categoría con menor puntaje', () {
      expect(_puntaje86.masResto, CategoriaPuntaje.frenadas);
      expect(
        _puntaje(giros: 60, velocidad: 70).masResto,
        CategoriaPuntaje.giros,
      );
    });

    test('en empate gana la de mayor peso', () {
      expect(
        _puntaje(aceleraciones: 80, velocidad: 80).masResto,
        CategoriaPuntaje.velocidad,
      );
      expect(
        _puntaje(giros: 80, frenadas: 80).masResto,
        CategoriaPuntaje.frenadas,
      );
    });

    test('con el mismo peso, el orden del desglose', () {
      expect(
        _puntaje(frenadas: 80, velocidad: 80).masResto,
        CategoriaPuntaje.frenadas,
      );
      expect(
        _puntaje(aceleraciones: 80, giros: 80).masResto,
        CategoriaPuntaje.aceleraciones,
      );
    });

    test('nada si todas están en 100', () {
      expect(_puntaje().masResto, isNull);
    });

    test('cantidad de eventos de cada categoría', () {
      expect(CategoriaPuntaje.frenadas.eventos(0), 'Sin eventos');
      expect(CategoriaPuntaje.frenadas.eventos(1), '1 frenada');
      expect(CategoriaPuntaje.aceleraciones.eventos(2), '2 aceleraciones');
      expect(CategoriaPuntaje.giros.eventos(1), '1 giro');
      expect(CategoriaPuntaje.velocidad.eventos(3), '3 excesos');
    });
  });

  group('Pantalla de resumen', () {
    testWidgets('muestra el DriveScore y su calificación', (tester) async {
      await _mostrarResumen(
        tester,
        ViajeTerminado(
          _resumen(),
          ResultadoViaje.finalizado,
          puntaje: _puntaje86,
        ),
      );
      expect(find.text('Viaje guardado'), findsOneWidget);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('DRIVESCORE DEL VIAJE'), findsOneWidget);
      expect(find.text('Muy bueno'), findsOneWidget);
      expect(find.text('Vel. máx.'), findsOneWidget);
      // Finalizado: la flecha abre el detalle (con el desglose)
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('con eventos: conteo por tipo y lo que más restó, sin '
        'desglose', (tester) async {
      await _mostrarResumen(
        tester,
        ViajeTerminado(
          _resumen(eventos: [_frenada]),
          ResultadoViaje.finalizado,
          puntaje: _puntaje86,
        ),
      );
      expect(find.text('Lo que más restó: frenadas'), findsOneWidget);
      // Contadores (HU-29): 1 frenada, el resto en 0
      for (final nombre in ['Frenadas', 'Aceleraciones', 'Giros', 'Excesos']) {
        expect(find.text(nombre), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
      // El desglose quedó en el detalle
      expect(find.text('PUNTAJE POR CATEGORÍA'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Sin ruta no hay mapa
      expect(find.text('Ver mapa completo'), findsNothing);
    });

    testWidgets('empate: lo que más restó es la de mayor peso', (tester) async {
      await _mostrarResumen(
        tester,
        ViajeTerminado(
          _resumen(eventos: [_exceso]),
          ResultadoViaje.finalizado,
          puntaje: _puntaje(aceleraciones: 82, velocidad: 82),
        ),
      );
      expect(find.text('Lo que más restó: velocidad'), findsOneWidget);
    });

    testWidgets('sin eventos: mensaje positivo', (tester) async {
      await _mostrarResumen(
        tester,
        ViajeTerminado(
          _resumen(eventos: []),
          ResultadoViaje.finalizado,
          puntaje: _puntaje(),
        ),
      );
      expect(find.text('Sin eventos de riesgo. ¡Sigue así!'), findsOneWidget);
      expect(find.textContaining('Lo que más restó'), findsNothing);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('pendiente: espera el puntaje y lo muestra al enviarse', (
      tester,
    ) async {
      final contenedor = await _mostrarResumen(
        tester,
        ViajeTerminado(_resumen(), ResultadoViaje.pendiente),
      );
      expect(find.textContaining('En el teléfono · '), findsOneWidget);
      expect(find.text('Calculando tu DriveScore'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.text('86'), findsNothing);
      // Aún no está en el historial: sin flecha al detalle
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // El reintento llegó al backend con la pantalla abierta
      contenedor
          .read(viajeProvider.notifier)
          .alEnviarResumen(
            7,
            const Envio(ResultadoEnvio.enviado, puntaje: _puntaje86),
          );
      await tester.pumpAndSettle();
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Muy bueno'), findsOneWidget);
      expect(find.text('Calculando tu DriveScore'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('sin puntaje disponible muestra un guion', (tester) async {
      await _mostrarResumen(
        tester,
        ViajeTerminado(_resumen(), ResultadoViaje.finalizado),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('DriveScore no disponible'), findsOneWidget);
    });
  });
}
