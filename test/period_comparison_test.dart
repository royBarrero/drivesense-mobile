import 'package:dio/dio.dart';
import 'package:drivesense/app/router.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/core/design/design.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/puntaje/data/score_repository.dart';
import 'package:drivesense/features/puntaje/models/period_comparison.dart';
import 'package:drivesense/features/puntaje/models/score_history.dart';
import 'package:drivesense/features/puntaje/presentation/period_comparison_screen.dart';
import 'package:drivesense/features/puntaje/presentation/score_history_screen.dart';
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

  Map<String, dynamic> Function(PeriodoComparativo periodo) respuesta;
  final pedidos = <(PeriodoComparativo, DateTime)>[];

  @override
  Future<ComparativoPuntaje> comparativo({
    required PeriodoComparativo periodo,
    required DateTime desde,
  }) async {
    pedidos.add((periodo, desde));
    return ComparativoPuntaje.fromJson(respuesta(periodo));
  }

  @override
  Future<HistoricoPuntaje> historico({required DateTime desde}) async =>
      HistoricoPuntaje(
        desde: desde,
        hasta: DateTime.now(),
        viajes: 0,
        viajesTotales: 0,
      );
}

Map<String, dynamic> _periodo({
  int viajes = 2,
  double distanciaM = 20000,
  int eventos = 1,
  int? drivescore = 97,
  String? calificacion = 'excelente',
  Map<String, int>? categorias = const {
    'frenadas': 89,
    'aceleraciones': 100,
    'giros': 94,
    'velocidad': 100,
  },
  double? eventosPor10Km = 0.5,
}) => {
  'desde': '2026-11-09T05:00:00Z',
  'hasta': '2026-11-13T20:00:00Z',
  'viajes': viajes,
  'distancia_m': distanciaM,
  'eventos': eventos,
  'drivescore': drivescore,
  'calificacion': calificacion,
  'categorias': categorias,
  'eventos_por_10km': eventosPor10Km,
};

Map<String, dynamic> _cambio(num diferencia, String resultado) => {
  'diferencia': diferencia,
  'resultado': resultado,
};

Map<String, dynamic> _comparable(String periodo) => {
  'periodo': periodo,
  'minimo_viajes': 2,
  'actual': _periodo(),
  'anterior': _periodo(
    viajes: 3,
    distanciaM: 31000,
    eventos: 6,
    drivescore: 90,
    categorias: const {
      'frenadas': 79,
      'aceleraciones': 100,
      'giros': 98,
      'velocidad': 100,
    },
    eventosPor10Km: 1.9,
  ),
  'comparable': true,
  'drivescore': _cambio(7, 'mejoro'),
  'categorias': {
    'frenadas': _cambio(10, 'mejoro'),
    'aceleraciones': _cambio(0, 'igual'),
    'giros': _cambio(-4, 'empeoro'),
    'velocidad': _cambio(0, 'igual'),
  },
  'eventos_por_10km': _cambio(-1.4, 'mejoro'),
  'viajes': -1,
  'distancia_m': -11000.0,
  'mas_mejoro': 'frenadas',
  'mas_empeoro': 'giros',
};

Map<String, dynamic> _sinDatos(String periodo) => {
  'periodo': periodo,
  'minimo_viajes': 2,
  'actual': _periodo(viajes: 1),
  'anterior': _periodo(
    viajes: 0,
    distanciaM: 0,
    eventos: 0,
    drivescore: null,
    calificacion: null,
    categorias: null,
    eventosPor10Km: null,
  ),
  'comparable': false,
  'drivescore': null,
  'categorias': null,
  'eventos_por_10km': null,
  'viajes': null,
  'distancia_m': null,
  'mas_mejoro': null,
  'mas_empeoro': null,
};

Future<_PuntajeFalso> _mostrar(
  WidgetTester tester,
  Map<String, dynamic> Function(PeriodoComparativo periodo) respuesta, {
  String inicial = Rutas.comparativo,
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
            routes: [
              GoRoute(
                path: 'comparar',
                builder: (_, _) => const ComparativoPantalla(),
              ),
            ],
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
        puntajeRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp.router(theme: temaClaro(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

Color? _color(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style?.color;

void main() {
  group('Modelo', () {
    test('lee la respuesta comparable', () {
      final c = ComparativoPuntaje.fromJson(_comparable('semana'));
      expect(c.periodo, PeriodoComparativo.semana);
      expect(c.comparable, isTrue);
      expect(c.actual.drivescore, 97);
      expect(c.actual.calificacion, Calificacion.excelente);
      expect(c.anterior.categorias![CategoriaPuntaje.giros], 98);
      expect(c.drivescore!.diferencia, 7);
      expect(
        c.categorias![CategoriaPuntaje.giros]!.resultado,
        ResultadoCambio.empeoro,
      );
      expect(c.eventosPor10Km!.diferencia, -1.4);
      expect(c.eventosPor10Km!.resultado, ResultadoCambio.mejoro);
      expect((c.viajes, c.distanciaM), (-1, -11000.0));
      expect(
        (c.masMejoro, c.masEmpeoro),
        (CategoriaPuntaje.frenadas, CategoriaPuntaje.giros),
      );
    });

    test('lee la respuesta sin datos', () {
      final c = ComparativoPuntaje.fromJson(_sinDatos('mes'));
      expect(c.periodo, PeriodoComparativo.mes);
      expect(c.comparable, isFalse);
      expect(c.drivescore, isNull);
      expect(c.categorias, isNull);
      expect(c.masMejoro, isNull);
      expect(c.anterior.drivescore, isNull);
      expect(c.anterior.eventosPor10Km, isNull);
    });

    test('la semana empieza el lunes y el mes el día 1, a medianoche', () {
      final jueves = DateTime(2026, 11, 12, 18, 30);
      expect(PeriodoComparativo.semana.desde(jueves), DateTime(2026, 11, 9));
      expect(PeriodoComparativo.mes.desde(jueves), DateTime(2026, 11));
      final lunes = DateTime(2026, 11, 9, 0, 5);
      expect(PeriodoComparativo.semana.desde(lunes), DateTime(2026, 11, 9));
    });

    test('manda la fecha con la zona del teléfono', () {
      final fecha = DateTime(2026, 11, 9);
      final texto = isoConZona(fecha);
      expect(texto, startsWith('2026-11-09T00:00:00'));
      expect(RegExp(r'[+-]\d\d:\d\d$').hasMatch(texto), isTrue);
      // Es el mismo instante
      expect(DateTime.parse(texto).isAtSameMomentAs(fecha), isTrue);
    });
  });

  group('Pantalla', () {
    testWidgets('compara la semana con la anterior', (tester) async {
      final repositorio = await _mostrar(tester, (p) => _comparable(p.name));
      expect(repositorio.pedidos.single.$1, PeriodoComparativo.semana);

      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Semana pasada'), findsOneWidget);
      expect(find.text('97'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('▲ 7 pts'), findsOneWidget);

      // Destacadas
      expect(find.text('Lo que más mejoró'), findsOneWidget);
      expect(find.text('▲ 10 pts'), findsOneWidget);
      expect(find.text('Lo que más empeoró'), findsOneWidget);
      expect(find.text('▼ 4 pts'), findsOneWidget);

      // Categorías con su cambio
      expect(find.text('▲ 10'), findsOneWidget);
      expect(find.text('▼ 4'), findsOneWidget);
      expect(find.text('='), findsNWidgets(2));

      final colores = ColoresDriveSense.claro;
      // Viajes y km: diferencia neutra
      expect(find.text('Semana pasada: 3'), findsOneWidget);
      expect(_color(tester, '▼ 1'), colores.textoSecundario);
      expect(find.text('Semana pasada: 31,0'), findsOneWidget);
      expect(_color(tester, '▼ 11,0'), colores.textoSecundario);
      // Menos eventos por distancia es mejora: ▼ en verde
      expect(find.text('Eventos cada 10 km'), findsOneWidget);
      expect(find.text('0,5'), findsOneWidget);
      expect(_color(tester, '▼ 1,4'), colores.primarioOscuro);
    });

    testWidgets('cambia al mes', (tester) async {
      final repositorio = await _mostrar(tester, (p) => _comparable(p.name));
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(repositorio.pedidos.last.$1, PeriodoComparativo.mes);
      expect(find.text('Este mes'), findsOneWidget);
      expect(find.text('Mes pasado'), findsOneWidget);
    });

    testWidgets('sin el mínimo de viajes: no hay datos para comparar', (
      tester,
    ) async {
      final repositorio = await _mostrar(
        tester,
        (p) => p == PeriodoComparativo.semana
            ? _sinDatos(p.name)
            : _comparable(p.name),
      );
      expect(find.text('No hay datos para comparar'), findsOneWidget);
      expect(
        find.text('Necesitas al menos 2 viajes en cada periodo.'),
        findsOneWidget,
      );
      expect(find.text('Esta semana: 1 · Semana pasada: 0'), findsOneWidget);
      expect(find.text('Lo que más mejoró'), findsNothing);

      await tester.tap(find.text('Ver mes'));
      await tester.pumpAndSettle();
      expect(repositorio.pedidos.last.$1, PeriodoComparativo.mes);
      expect(find.text('Este mes'), findsOneWidget);
    });

    testWidgets('sin destacadas si ninguna categoría cambió', (tester) async {
      await _mostrar(
        tester,
        (p) => {
          ..._comparable(p.name),
          'mas_mejoro': null,
          'mas_empeoro': null,
        },
      );
      expect(find.text('Lo que más mejoró'), findsNothing);
      expect(find.text('Lo que más empeoró'), findsNothing);
    });

    testWidgets('sin conexión: aviso y reintentar', (tester) async {
      await _mostrar(
        tester,
        (p) => throw const ErrorApi(mensaje: 'Sin conexión'),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('Mi DriveScore abre el comparativo', (tester) async {
      await _mostrar(
        tester,
        (p) => _comparable(p.name),
        inicial: Rutas.miDriveScore,
      );
      expect(find.text('Comparar periodos'), findsOneWidget);
      await tester.tap(find.text('Comparar periodos'));
      await tester.pumpAndSettle();
      expect(find.byType(ComparativoPantalla), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
    });
  });
}
