import 'package:dio/dio.dart';
import 'package:drivesense/app/router.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/puntaje/data/score_repository.dart';
import 'package:drivesense/features/puntaje/models/score_history.dart';
import 'package:drivesense/features/puntaje/presentation/score_history_screen.dart';
import 'package:drivesense/features/puntaje/presentation/widgets/score_chart.dart';
import 'package:drivesense/features/recorridos/models/trip_score.dart';
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

/// Repositorio sin red: [respuesta] decide qué devuelve cada periodo.
class _PuntajeFalso extends PuntajeRepositorio {
  _PuntajeFalso(this.respuesta) : super(Dio());

  HistoricoPuntaje Function(DateTime desde) respuesta;
  final pedidos = <DateTime>[];

  @override
  Future<HistoricoPuntaje> historico({required DateTime desde}) async {
    pedidos.add(desde);
    return respuesta(desde);
  }
}

final _ahora = DateTime.now();

List<PuntoHistorico> _puntos(List<int> puntajes) => [
  for (final (i, puntaje) in puntajes.indexed)
    PuntoHistorico(
      fecha: _ahora.subtract(Duration(days: puntajes.length - i)),
      drivescore: puntaje,
      viajes: 1,
    ),
];

HistoricoPuntaje _historico({
  DateTime? desde,
  int viajes = 12,
  int viajesTotales = 20,
  int? promedioTotal = 85,
  int? promedio = 86,
  int? tendencia = 6,
  List<int> puntos = const [80, 84, 78, 88, 90],
  Map<CategoriaPuntaje, PromedioCategoria>? categorias,
  ViajeDestacado? mejor,
  ViajeDestacado? peor,
}) => HistoricoPuntaje(
  desde: desde ?? _ahora.subtract(const Duration(days: 29)),
  hasta: _ahora,
  viajes: viajes,
  viajesTotales: viajesTotales,
  promedioTotal: promedioTotal,
  promedio: viajes == 0 ? null : promedio,
  calificacion: viajes == 0 || promedio == null
      ? null
      : Calificacion.de(promedio),
  tendencia: viajes == 0 ? null : tendencia,
  puntos: viajes == 0 ? const [] : _puntos(puntos),
  categorias: viajes == 0 ? null : categorias,
  mejor: viajes == 0 ? null : mejor,
  peor: viajes == 0 ? null : peor,
);

final _mejor = ViajeDestacado(
  id: 5,
  fecha: DateTime(2026, 9, 28, 10),
  distanciaM: 12100,
  drivescore: 97,
);

final _peor = ViajeDestacado(
  id: 8,
  fecha: DateTime(2026, 9, 9, 18),
  distanciaM: 4300,
  drivescore: 68,
);

/// Mi DriveScore (sobre un Inicio vacío) y un detalle de viaje de mentira.
Future<_PuntajeFalso> _mostrar(
  WidgetTester tester,
  HistoricoPuntaje Function(DateTime desde) respuesta, {
  String inicial = Rutas.inicio,
}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final repositorio = _PuntajeFalso(respuesta);
  final router = GoRouter(
    initialLocation: inicial,
    routes: [
      GoRoute(
        path: Rutas.inicio,
        builder: (_, _) => const Scaffold(body: Text('Inicio')),
        routes: [
          GoRoute(
            path: 'drivescore',
            builder: (_, _) => const MiDriveScorePantalla(),
          ),
        ],
      ),
      GoRoute(
        path: '${Rutas.viajes}/:id',
        builder: (_, estado) => Text('Detalle ${estado.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        puntajeRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp.router(theme: temaClaro(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

Finder _pintor(Type widget) => find.descendant(
  of: find.byType(widget),
  matching: find.byType(CustomPaint),
);

DateTime _soloDia(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

void main() {
  group('Modelo', () {
    test('lee la respuesta del histórico', () {
      final historico = HistoricoPuntaje.fromJson({
        'desde': '2026-09-28T04:00:00Z',
        'hasta': '2026-10-04T20:00:00Z',
        'viajes': 2,
        'viajes_totales': 9,
        'promedio_total': 83,
        'promedio': 86,
        'calificacion': 'muy_bueno',
        'tendencia': -2,
        'agrupacion': 'viaje',
        'puntos': [
          {'fecha': '2026-09-29T12:00:00Z', 'drivescore': 90, 'viajes': 1},
          {'fecha': '2026-10-02T12:00:00Z', 'drivescore': 80, 'viajes': 1},
        ],
        'categorias': {
          'frenadas': {'promedio': 79, 'diferencia': 5},
          'aceleraciones': {'promedio': 94, 'diferencia': 0},
          'giros': {'promedio': 85, 'diferencia': null},
          'velocidad': {'promedio': 90, 'diferencia': -2},
        },
        'mejor': {
          'id': 5,
          'fecha_inicio': '2026-09-29T12:00:00Z',
          'distancia_m': 12100,
          'drivescore': 90,
        },
        'peor': null,
      });
      expect(historico.calificacion, Calificacion.muyBueno);
      expect(historico.tendencia, -2);
      expect(historico.puntos.map((p) => p.drivescore), [90, 80]);
      expect(historico.categorias![CategoriaPuntaje.frenadas]!.diferencia, 5);
      expect(historico.categorias![CategoriaPuntaje.giros]!.diferencia, isNull);
      expect(historico.mejor!.id, 5);
      expect(historico.peor, isNull);
      expect(historico.promedioTotal, 83);
    });

    test('cada periodo empieza a medianoche, contando hoy', () {
      final ahora = DateTime(2026, 10, 4, 15, 30);
      expect(PeriodoPuntaje.dias7.desde(ahora), DateTime(2026, 9, 28));
      expect(PeriodoPuntaje.dias30.desde(ahora), DateTime(2026, 9, 5));
      expect(PeriodoPuntaje.meses3.desde(ahora), DateTime(2026, 7, 7));
    });
  });

  group('Mi DriveScore', () {
    testWidgets(
      'promedio, calificación, viajes y tendencia; cambia de periodo',
      (tester) async {
        final repositorio = await _mostrar(
          tester,
          (desde) => _historico(desde: desde),
          inicial: Rutas.miDriveScore,
        );

        expect(find.text('Promedio · 12 viajes'), findsOneWidget);
        expect(find.text('86'), findsOneWidget);
        expect(find.text('Muy bueno'), findsOneWidget);
        expect(find.text('▲ 6 pts'), findsOneWidget);
        expect(find.byType(GraficoDriveScore), findsOneWidget);
        expect(find.text('Hoy'), findsOneWidget);

        await tester.tap(find.text('3 meses'));
        await tester.pumpAndSettle();
        expect(repositorio.pedidos, hasLength(2));
        expect(
          _soloDia(repositorio.pedidos.last),
          _soloDia(PeriodoPuntaje.meses3.desde(DateTime.now())),
        );
      },
    );

    testWidgets('periodo sin viajes: aviso y cambio de periodo', (
      tester,
    ) async {
      final repositorio = await _mostrar(
        tester,
        (desde) => desde.isBefore(PeriodoPuntaje.dias7.desde(DateTime.now()))
            ? _historico(desde: desde, viajes: 2)
            : _historico(desde: desde, viajes: 0),
        inicial: Rutas.miDriveScore,
      );

      expect(
        find.text('No tienes viajes en los últimos 7 días'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver 30 días'));
      await tester.pumpAndSettle();
      expect(repositorio.pedidos, hasLength(2));
      expect(find.text('Promedio · 2 viajes'), findsOneWidget);
    });

    testWidgets('promedio por categoría con su cambio', (tester) async {
      await _mostrar(
        tester,
        (desde) => _historico(
          categorias: const {
            CategoriaPuntaje.frenadas: PromedioCategoria(
              promedio: 79,
              diferencia: 5,
            ),
            CategoriaPuntaje.aceleraciones: PromedioCategoria(
              promedio: 94,
              diferencia: 0,
            ),
            CategoriaPuntaje.giros: PromedioCategoria(
              promedio: 85,
              diferencia: 3,
            ),
            CategoriaPuntaje.velocidad: PromedioCategoria(
              promedio: 90,
              diferencia: -2,
            ),
          },
        ),
        inicial: Rutas.miDriveScore,
      );

      expect(find.text('PROMEDIO POR CATEGORÍA'), findsOneWidget);
      for (final categoria in CategoriaPuntaje.values) {
        expect(find.text(categoria.nombre), findsOneWidget);
      }
      expect(find.text('▲ 5'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text('▲ 3'), findsOneWidget);
      expect(find.text('▼ 2'), findsOneWidget);
    });

    testWidgets('sin periodo anterior, las categorías no muestran cambio', (
      tester,
    ) async {
      await _mostrar(
        tester,
        (desde) => _historico(
          tendencia: null,
          categorias: {
            for (final categoria in CategoriaPuntaje.values)
              categoria: const PromedioCategoria(promedio: 90),
          },
        ),
        inicial: Rutas.miDriveScore,
      );
      expect(find.textContaining('▲'), findsNothing);
      expect(find.textContaining('▼'), findsNothing);
      expect(find.text('='), findsNothing);
    });

    testWidgets('mejor y peor viaje abren su detalle', (tester) async {
      await _mostrar(
        tester,
        (desde) => _historico(mejor: _mejor, peor: _peor),
        inicial: Rutas.miDriveScore,
      );

      expect(find.text('Mejor viaje'), findsOneWidget);
      expect(find.text('97'), findsOneWidget);
      expect(find.text('28 sep · 12,1 km'), findsOneWidget);
      expect(find.text('Viaje más bajo'), findsOneWidget);
      expect(find.text('9 sep · 4,30 km'), findsOneWidget);

      await tester.tap(find.text('Mejor viaje'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle 5'), findsOneWidget);
    });

    testWidgets('con un solo punto el gráfico dibuja solo el punto', (
      tester,
    ) async {
      await _mostrar(
        tester,
        (desde) => _historico(viajes: 1, puntos: [88], mejor: _mejor),
        inicial: Rutas.miDriveScore,
      );
      expect(_pintor(GraficoDriveScore), paints..circle());
      expect(_pintor(GraficoDriveScore), paintsExactlyCountTimes(#drawPath, 0));
      // Con un solo viaje no hay "más bajo"
      expect(find.text('Viaje más bajo'), findsNothing);
    });

    testWidgets('sin conexión: aviso y reintentar', (tester) async {
      await _mostrar(
        tester,
        (desde) => throw const ErrorApi(mensaje: 'Sin conexión'),
        inicial: Rutas.miDriveScore,
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
