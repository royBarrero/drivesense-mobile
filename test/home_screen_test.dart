import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drivesense/app/router.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/inicio/presentation/home_screen.dart';
import 'package:drivesense/features/puntaje/data/score_repository.dart';
import 'package:drivesense/features/puntaje/models/score_history.dart';
import 'package:drivesense/features/recorridos/data/trips_repository.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/models/trip_history.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/drive_score_ring.dart';
import 'package:drivesense/features/recorridos/providers/pending_summary_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _usuario = Usuario(
  id: 1,
  nombre: 'Ana Pérez',
  email: 'ana@prueba.com',
  telefono: '70000001',
  rol: 'conductor',
  debeCambiarContrasenia: false,
);

class _SesionFija extends SesionNotifier {
  @override
  Future<Usuario?> build() async => _usuario;
}

class _ViajeFijo extends ViajeNotifier {
  _ViajeFijo(this._estado);

  final EstadoViaje _estado;

  @override
  Future<EstadoViaje> build() async => _estado;
}

class _PendienteFijo extends ResumenPendienteNotifier {
  _PendienteFijo(this._resumen);

  final ResumenRecorrido? _resumen;

  @override
  Future<ResumenRecorrido?> build() async => _resumen;
}

/// Histórico del DriveScore sin red: [respuesta] lo decide (puede no terminar).
class _PuntajeFalso extends PuntajeRepositorio {
  _PuntajeFalso(this.respuesta) : super(Dio());

  Future<HistoricoPuntaje> Function() respuesta;
  var pedidos = 0;

  @override
  Future<HistoricoPuntaje> historico({required DateTime desde}) {
    pedidos++;
    return respuesta();
  }
}

/// Historial sin red: la semana ([semana]) y el último viaje ([ultimo]).
class _RecorridosFalso extends RecorridosRepositorio {
  _RecorridosFalso({required this.semana, this.ultimo}) : super(Dio());

  final ResumenPeriodo semana;
  final RecorridoHistorial? ultimo;

  @override
  Future<PaginaHistorial> listar({
    DateTime? desde,
    int? antesDe,
    int limite = 20,
  }) async => PaginaHistorial(
    recorridos: [?ultimo],
    siguiente: null,
    resumen: desde == null
        ? const ResumenPeriodo(viajes: 9, distanciaM: 90000, duracionS: 9000)
        : semana,
  );
}

final _hoy = DateTime.now();

HistoricoPuntaje _historico({
  int viajes = 4,
  int viajesTotales = 8,
  int? promedioTotal = 85,
  int? promedio = 87,
  int? tendencia = 4,
}) => HistoricoPuntaje(
  desde: _hoy.subtract(const Duration(days: 6)),
  hasta: _hoy,
  viajes: viajes,
  viajesTotales: viajesTotales,
  promedioTotal: promedioTotal,
  promedio: viajes == 0 ? null : promedio,
  tendencia: viajes == 0 ? null : tendencia,
);

RecorridoHistorial _viaje({int? drivescore = 91}) => RecorridoHistorial(
  id: 9,
  salida: DateTime(_hoy.year, _hoy.month, _hoy.day, 8, 10),
  llegada: DateTime(_hoy.year, _hoy.month, _hoy.day, 8, 42),
  distanciaM: 16200,
  duracionS: 1920,
  velocidadMaximaKmh: 70,
  velocidadPromedioKmh: 30,
  drivescore: drivescore,
);

const _semana = ResumenPeriodo(viajes: 3, distanciaM: 42400, duracionS: 5100);

final _viajeActivo = ViajeActivo(
  recorridoId: 3,
  fechaInicioServidor: DateTime.now(),
  acumulador: AcumuladorRecorrido(inicio: DateTime.now()),
);

final _pendiente = ResumenRecorrido(
  recorridoId: 2,
  fechaFin: DateTime.now(),
  distanciaM: 1000,
  duracionS: 300,
  velocidadMaximaKmh: 40,
  velocidadPromedioKmh: 12,
  latitudFin: 0,
  longitudFin: 0,
);

/// Inicio con rutas de mentira para Mi DriveScore, Viajes y el detalle.
Future<_PuntajeFalso> _mostrar(
  WidgetTester tester, {
  Future<HistoricoPuntaje> Function()? historico,
  RecorridoHistorial? ultimo,
  EstadoViaje viaje = const SinViaje(),
  ResumenRecorrido? pendiente,
  DateTime? ahora,
  bool esperar = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final puntaje = _PuntajeFalso(historico ?? () async => _historico());
  final router = GoRouter(
    initialLocation: Rutas.inicio,
    routes: [
      GoRoute(
        path: Rutas.inicio,
        builder: (_, _) => Scaffold(
          body: InicioPantalla(reloj: () => ahora ?? DateTime(2026, 10, 4, 15)),
        ),
        routes: [
          GoRoute(
            path: 'drivescore',
            builder: (_, _) => const Text('Pantalla Mi DriveScore'),
          ),
        ],
      ),
      GoRoute(
        path: Rutas.viajes,
        builder: (_, _) => const Text('Pantalla Viajes'),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, estado) =>
                Text('Detalle ${estado.pathParameters['id']}'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        viajeProvider.overrideWith(() => _ViajeFijo(viaje)),
        resumenPendienteProvider.overrideWith(() => _PendienteFijo(pendiente)),
        puntajeRepositorioProvider.overrideWithValue(puntaje),
        recorridosRepositorioProvider.overrideWithValue(
          _RecorridosFalso(semana: _semana, ultimo: ultimo),
        ),
      ],
      child: MaterialApp.router(theme: temaClaro(), routerConfig: router),
    ),
  );
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return puntaje;
}

/// Números sueltos dentro de la tarjeta del último viaje (la cápsula).
Finder _numerosEnUltimoViaje() => find.descendant(
  of: find.ancestor(
    of: find.textContaining('Último viaje'),
    matching: find.byType(InkWell),
  ),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && RegExp(r'^\d+$').hasMatch(widget.data ?? ''),
  ),
);

void main() {
  group('Encabezado', () {
    testWidgets(
      'con tendencia: anillo y cápsula; el anillo abre Mi DriveScore',
      (tester) async {
        await _mostrar(tester);

        expect(find.text('87'), findsOneWidget);
        expect(find.text('DriveScore'), findsOneWidget);
        expect(find.text('▲ 4 pts en 7 días'), findsOneWidget);

        await tester.tap(find.byType(AnilloDriveScore));
        await tester.pumpAndSettle();
        expect(find.text('Pantalla Mi DriveScore'), findsOneWidget);
      },
    );

    testWidgets('si empeoró, la cápsula baja', (tester) async {
      await _mostrar(tester, historico: () async => _historico(tendencia: -3));
      expect(find.text('▼ 3 pts en 7 días'), findsOneWidget);
    });

    testWidgets('sin tendencia: sin cápsula', (tester) async {
      await _mostrar(
        tester,
        historico: () async => _historico(tendencia: null),
      );
      expect(find.text('87'), findsOneWidget);
      expect(find.textContaining('pts'), findsNothing);
    });

    testWidgets('sin viajes: guion, aviso y sin último viaje', (tester) async {
      await _mostrar(
        tester,
        historico: () async =>
            _historico(viajes: 0, viajesTotales: 0, promedioTotal: null),
      );

      expect(find.text('—'), findsOneWidget);
      expect(
        find.text('Tu DriveScore aparecerá después de tu primer viaje'),
        findsOneWidget,
      );
      expect(find.textContaining('Último viaje'), findsNothing);

      // Sin viajes con puntaje, el anillo no abre nada
      await tester.tap(find.byType(AnilloDriveScore));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Mi DriveScore'), findsNothing);
    });

    testWidgets('menos de 3 viajes: promedio de todos y cuántos faltan', (
      tester,
    ) async {
      await _mostrar(
        tester,
        // Su único viaje es de hace más de 7 días
        historico: () async =>
            _historico(viajes: 0, viajesTotales: 1, promedioTotal: 84),
      );
      expect(find.text('84'), findsOneWidget);
      expect(
        find.text('Haz 2 viajes más para ver tu evolución'),
        findsOneWidget,
      );
    });

    testWidgets('con 2 viajes falta uno', (tester) async {
      await _mostrar(
        tester,
        historico: () async =>
            _historico(viajes: 2, viajesTotales: 2, promedioTotal: 80),
      );
      expect(find.text('80'), findsOneWidget);
      expect(
        find.text('Haz 1 viaje más para ver tu evolución'),
        findsOneWidget,
      );
    });

    testWidgets('3 o más, pero ninguno en 7 días: guion y aviso', (
      tester,
    ) async {
      await _mostrar(tester, historico: () async => _historico(viajes: 0));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Sin viajes en los últimos 7 días'), findsOneWidget);
    });

    testWidgets('cargando: guion y el mismo alto que con datos', (
      tester,
    ) async {
      final respuesta = Completer<HistoricoPuntaje>();
      await _mostrar(tester, historico: () => respuesta.future, esperar: false);
      expect(find.text('—'), findsOneWidget);
      final botonCargando = tester.getTopLeft(find.text('Iniciar recorrido'));

      respuesta.complete(_historico());
      await tester.pumpAndSettle();
      expect(find.text('▲ 4 pts en 7 días'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Iniciar recorrido')), botonCargando);
    });

    testWidgets('error: aviso y reintentar', (tester) async {
      var fallar = true;
      final puntaje = await _mostrar(
        tester,
        historico: () async {
          if (fallar) throw const ErrorApi(mensaje: 'Sin conexión');
          return _historico();
        },
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('No se pudo cargar tu DriveScore.'), findsOneWidget);

      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(puntaje.pedidos, 2);
      expect(find.text('87'), findsOneWidget);
    });
  });

  group('Saludo según la hora', () {
    test('días hasta las 12, tardes hasta las 19, noches después', () {
      expect(saludoSegunHora(DateTime(2026, 10, 4, 0, 30)), 'Buenos días');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 9)), 'Buenos días');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 11, 59)), 'Buenos días');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 12)), 'Buenas tardes');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 18, 59)), 'Buenas tardes');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 19)), 'Buenas noches');
      expect(saludoSegunHora(DateTime(2026, 10, 4, 23, 30)), 'Buenas noches');
    });

    testWidgets('la pantalla saluda con el primer nombre', (tester) async {
      await _mostrar(tester, ahora: DateTime(2026, 10, 4, 9, 15));
      expect(find.text('Buenos días,'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('de noche', (tester) async {
      await _mostrar(tester, ahora: DateTime(2026, 10, 4, 20));
      expect(find.text('Buenas noches,'), findsOneWidget);
    });
  });

  group('Esta semana', () {
    testWidgets('viajes, km y tiempo al volante; "Mis viajes" va a Viajes', (
      tester,
    ) async {
      await _mostrar(tester);

      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('1h 25m'), findsOneWidget);
      expect(find.text('Al volante'), findsOneWidget);

      await tester.tap(find.text('Mis viajes'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Viajes'), findsOneWidget);
    });
  });

  group('Último viaje', () {
    testWidgets('con puntaje: hora, distancia, duración y la cápsula; abre el '
        'detalle', (tester) async {
      await _mostrar(tester, ultimo: _viaje());

      expect(find.text('Último viaje · Hoy 08:10'), findsOneWidget);
      expect(find.text('16,2 km · 32 min'), findsOneWidget);
      expect(_numerosEnUltimoViaje(), findsOneWidget);
      expect(find.text('91'), findsOneWidget);

      await tester.tap(find.text('16,2 km · 32 min'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle 9'), findsOneWidget);
    });

    testWidgets('sin puntaje (anterior a HU-15): sin cápsula', (tester) async {
      await _mostrar(tester, ultimo: _viaje(drivescore: null));
      expect(find.text('Último viaje · Hoy 08:10'), findsOneWidget);
      expect(_numerosEnUltimoViaje(), findsNothing);
    });
  });

  group('Botón del recorrido', () {
    testWidgets('sin viaje: iniciar', (tester) async {
      await _mostrar(tester);
      expect(find.text('Iniciar recorrido'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.textContaining('pendiente de envío'), findsNothing);
    });

    testWidgets('con un viaje en curso no se ofrece iniciar otro', (
      tester,
    ) async {
      await _mostrar(
        tester,
        viaje: ViajeEnCurso(viaje: _viajeActivo, ahora: DateTime.now()),
        esperar: false,
      );
      expect(find.text('Volver al viaje'), findsOneWidget);
      expect(find.text('Iniciar recorrido'), findsNothing);
    });

    testWidgets('un viaje interrumpido ofrece continuar o finalizar', (
      tester,
    ) async {
      await _mostrar(tester, viaje: ViajeInterrumpido(_viajeActivo));
      expect(find.text('Continuar viaje'), findsOneWidget);
      expect(
        find.textContaining('Tienes un viaje sin terminar'),
        findsOneWidget,
      );
      expect(find.text('Finalizar'), findsOneWidget);
    });

    testWidgets('avisa de un resumen pendiente de envío', (tester) async {
      await _mostrar(tester, pendiente: _pendiente);
      expect(find.textContaining('pendiente de envío'), findsOneWidget);
    });
  });
}
