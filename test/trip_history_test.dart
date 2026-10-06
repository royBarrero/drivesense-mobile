import 'package:dio/dio.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/recorridos/data/trips_repository.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_history.dart';
import 'package:drivesense/features/recorridos/models/trip_score.dart';
import 'package:drivesense/features/recorridos/presentation/trip_detail_screen.dart';
import 'package:drivesense/features/recorridos/presentation/trips_screen.dart';
import 'package:drivesense/features/recorridos/providers/pending_summary_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_history_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/trip_map.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

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
  @override
  Future<EstadoViaje> build() async => const SinViaje();
}

class _PendienteFijo extends ResumenPendienteNotifier {
  @override
  Future<ResumenRecorrido?> build() async => null;
}

typedef _Pedido = ({DateTime? desde, int? antesDe, int limite});

/// Repositorio sin red: [paginas] decide la respuesta de cada `listar`.
class _RepositorioFalso extends RecorridosRepositorio {
  _RepositorioFalso({required this.paginas, this.detalle}) : super(Dio());

  PaginaHistorial Function(_Pedido pedido) paginas;
  RecorridoHistorial Function(int id)? detalle;
  final pedidos = <_Pedido>[];

  @override
  Future<PaginaHistorial> listar({
    DateTime? desde,
    int? antesDe,
    int limite = 20,
  }) async {
    final pedido = (desde: desde, antesDe: antesDe, limite: limite);
    pedidos.add(pedido);
    return paginas(pedido);
  }

  @override
  Future<RecorridoHistorial> obtener(int id) async => detalle!(id);
}

RecorridoHistorial _recorrido(
  int id,
  DateTime salida, {
  int minutos = 18,
  PuntajeViaje? puntaje,
  Map<TipoEvento, int>? eventosPorTipo,
  List<PuntoRuta>? ruta,
  List<EventoRiesgo>? eventos,
}) => RecorridoHistorial(
  id: id,
  salida: salida,
  llegada: salida.add(Duration(minutes: minutos)),
  distanciaM: 7400,
  duracionS: minutos * 60,
  velocidadMaximaKmh: 62,
  velocidadPromedioKmh: 24,
  puntaje: puntaje,
  eventosPorTipo: eventosPorTipo,
  ruta: ruta,
  eventos: eventos,
);

List<PuntoRuta> _ruta(DateTime salida) => [
  for (var i = 0; i < 5; i++)
    PuntoRuta(
      latitud: -17.78 + i * 0.001,
      longitud: -63.18 + i * 0.001,
      fecha: salida.add(Duration(minutes: i)),
      velocidadKmh: 30,
    ),
];

Map<TipoEvento, int> _conteo({
  int frenadas = 0,
  int aceleraciones = 0,
  int giros = 0,
  int excesos = 0,
}) => {
  TipoEvento.frenadaBrusca: frenadas,
  TipoEvento.aceleracionSevera: aceleraciones,
  TipoEvento.giroAgresivo: giros,
  TipoEvento.excesoVelocidad: excesos,
};

const _resumenVacio = ResumenPeriodo(viajes: 0, distanciaM: 0, duracionS: 0);

PaginaHistorial _vacia() => const PaginaHistorial(
  recorridos: [],
  siguiente: null,
  resumen: _resumenVacio,
);

List<Override> _overrides(_RepositorioFalso repositorio) => [
  sesionProvider.overrideWith(_SesionFija.new),
  viajeProvider.overrideWith(_ViajeFijo.new),
  resumenPendienteProvider.overrideWith(_PendienteFijo.new),
  recorridosRepositorioProvider.overrideWithValue(repositorio),
];

Future<void> _mostrar(
  WidgetTester tester,
  Widget pantalla,
  _RepositorioFalso repositorio,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repositorio),
      child: MaterialApp(
        theme: temaClaro(),
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final hoy = DateTime.now();
  final manana = DateTime(hoy.year, hoy.month, hoy.day, 8, 10);
  final tarde = DateTime(hoy.year, hoy.month, hoy.day, 18, 30);
  final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1, 19, 5);

  group('Mis viajes', () {
    testWidgets('resumen y lista agrupada por día', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => PaginaHistorial(
          recorridos: [
            _recorrido(3, tarde),
            _recorrido(2, manana, minutos: 32),
            _recorrido(1, ayer, minutos: 12),
          ],
          siguiente: null,
          resumen: const ResumenPeriodo(
            viajes: 3,
            distanciaM: 142000,
            duracionS: 13200,
          ),
        ),
      );
      await _mostrar(tester, const ViajesPantalla(), repositorio);

      expect(find.text('Mis viajes'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Al volante'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('18:30 – 18:48'), findsOneWidget);
      expect(find.text('18 min · máx. 62 km/h'), findsOneWidget);
      expect(find.text('32 min · máx. 62 km/h'), findsOneWidget);
      // Primera página de "Esta semana": desde el lunes, sin cursor
      final pedido = repositorio.pedidos.single;
      expect(pedido.desde, PeriodoHistorial.semana.desde(DateTime.now()));
      expect(pedido.antesDe, isNull);
    });

    testWidgets('al cambiar de filtro pide el periodo nuevo', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => PaginaHistorial(
          recorridos: [_recorrido(1, tarde)],
          siguiente: null,
          resumen: const ResumenPeriodo(
            viajes: 1,
            distanciaM: 7400,
            duracionS: 1080,
          ),
        ),
      );
      await _mostrar(tester, const ViajesPantalla(), repositorio);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      expect(repositorio.pedidos.last.desde, isNull);
    });

    testWidgets('sin ningún viaje: ilustración e iniciar recorrido', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso(paginas: (_) => _vacia());
      await _mostrar(tester, const ViajesPantalla(), repositorio);

      expect(find.text('Aún no tienes viajes'), findsOneWidget);
      expect(
        find.text(
          'Tus recorridos aparecerán aquí cuando finalices tu primer viaje.',
        ),
        findsOneWidget,
      );
      expect(find.text('Iniciar recorrido'), findsOneWidget);
      expect(find.text('Esta semana'), findsNothing, reason: 'sin filtros');
      // Se confirmó que no hay viajes en ningún periodo
      expect(repositorio.pedidos.last, (desde: null, antesDe: null, limite: 1));
    });

    testWidgets('periodo vacío con viajes anteriores: filtros y aviso', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso(
        paginas: (pedido) => pedido.desde == null
            ? PaginaHistorial(
                recorridos: [_recorrido(1, ayer)],
                siguiente: null,
                resumen: null,
              )
            : _vacia(),
      );
      await _mostrar(tester, const ViajesPantalla(), repositorio);

      expect(find.text('No tienes viajes esta semana.'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Aún no tienes viajes'), findsNothing);
    });

    testWidgets('sin conexión: aviso y reintentar', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => throw const ErrorApi(mensaje: ErrorApi.sinConexion),
      );
      await _mostrar(tester, const ViajesPantalla(), repositorio);

      expect(find.text('Sin conexión'), findsOneWidget);

      repositorio.paginas = (_) => PaginaHistorial(
        recorridos: [_recorrido(1, tarde)],
        siguiente: null,
        resumen: const ResumenPeriodo(
          viajes: 1,
          distanciaM: 7400,
          duracionS: 1080,
        ),
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión'), findsNothing);
      expect(find.text('18:30 – 18:48'), findsOneWidget);
    });
  });

  test('cargarMas agrega la página siguiente con el mismo desde', () async {
    final repositorio = _RepositorioFalso(
      paginas: (pedido) => pedido.antesDe == null
          ? PaginaHistorial(
              recorridos: [_recorrido(9, tarde), _recorrido(8, manana)],
              siguiente: 8,
              resumen: const ResumenPeriodo(
                viajes: 3,
                distanciaM: 22200,
                duracionS: 3240,
              ),
            )
          : PaginaHistorial(
              recorridos: [_recorrido(5, ayer)],
              siguiente: null,
              resumen: null,
            ),
    );
    final contenedor = ProviderContainer(overrides: _overrides(repositorio));
    addTearDown(contenedor.dispose);
    final proveedor = historialProvider(PeriodoHistorial.mes);
    // Mantiene vivo el provider mientras dura la prueba
    contenedor.listen(proveedor, (_, _) {});

    final primera = await contenedor.read(proveedor.future);
    expect(primera.hayMas, isTrue);

    await contenedor.read(proveedor.notifier).cargarMas();
    final estado = contenedor.read(proveedor).value!;

    expect(estado.recorridos.map((r) => r.id), [9, 8, 5]);
    expect(estado.hayMas, isFalse);
    expect(estado.resumen.viajes, 3, reason: 'el resumen es el del periodo');
    expect(repositorio.pedidos.last.antesDe, 8);
    expect(repositorio.pedidos.last.desde, repositorio.pedidos.first.desde);

    // Sin más páginas no vuelve a pedir
    await contenedor.read(proveedor.notifier).cargarMas();
    expect(repositorio.pedidos, hasLength(2));
  });

  group('Detalle del viaje', () {
    testWidgets('muestra salida, llegada y métricas', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (id) => _recorrido(id, tarde),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 3),
        repositorio,
      );

      expect(find.text('Detalle del viaje'), findsOneWidget);
      expect(find.textContaining('Hoy · '), findsOneWidget);
      expect(find.text('Salida'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('18:48'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Vel. máx.'), findsOneWidget);
      expect(find.text('Vel. prom.'), findsOneWidget);
      // Sin DriveScore (anterior a HU-15): sin anillo ni desglose
      expect(find.text('DRIVESCORE'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('DriveScore con su desglose y los eventos de cada tipo', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (id) => _recorrido(
          id,
          tarde,
          puntaje: const PuntajeViaje(
            drivescore: 86,
            frenadas: 70,
            aceleraciones: 100,
            giros: 76,
            velocidad: 100,
          ),
          eventosPorTipo: _conteo(frenadas: 1, giros: 1),
        ),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 3),
        repositorio,
      );

      expect(find.text('DRIVESCORE'), findsOneWidget);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Muy bueno'), findsOneWidget);
      expect(find.text('Lo que más restó: frenadas'), findsOneWidget);
      // Contadores (HU-29): 1 frenada y 1 giro; el desglose ya no los repite
      expect(find.text('Excesos'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('1 frenada'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
      expect(find.text('Vel. máx.'), findsOneWidget);
    });

    testWidgets('empate: lo que más restó es la de mayor peso', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (id) => _recorrido(
          id,
          tarde,
          puntaje: const PuntajeViaje(
            drivescore: 93,
            frenadas: 100,
            aceleraciones: 82,
            giros: 100,
            velocidad: 82,
          ),
          eventosPorTipo: _conteo(aceleraciones: 1, excesos: 1),
        ),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 3),
        repositorio,
      );

      expect(find.text('Lo que más restó: velocidad'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('sin eventos: mensaje positivo', (tester) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (id) => _recorrido(
          id,
          tarde,
          puntaje: const PuntajeViaje(
            drivescore: 100,
            frenadas: 100,
            aceleraciones: 100,
            giros: 100,
            velocidad: 100,
          ),
          eventosPorTipo: _conteo(),
        ),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 3),
        repositorio,
      );

      expect(find.text('Excelente'), findsOneWidget);
      expect(find.text('Sin eventos de riesgo. ¡Sigue así!'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('con ruta (HU-29): el mapa en lugar del degradado', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (id) => _recorrido(
          id,
          tarde,
          puntaje: const PuntajeViaje(
            drivescore: 86,
            frenadas: 70,
            aceleraciones: 100,
            giros: 76,
            velocidad: 100,
          ),
          eventosPorTipo: _conteo(frenadas: 1),
          ruta: _ruta(tarde),
          eventos: [
            EventoRiesgo(
              tipo: TipoEvento.frenadaBrusca,
              fecha: tarde.add(const Duration(minutes: 2)),
              intensidad: 3.4,
              latitud: -17.778,
              longitud: -63.178,
              velocidadPreviaMs: 10,
            ),
          ],
        ),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 3),
        repositorio,
      );

      expect(find.byType(MapaViaje), findsOneWidget);
      expect(find.text('Detalle del viaje'), findsOneWidget);
      // Fecha y horas en una línea, sin la tarjeta de salida y llegada
      expect(find.textContaining('Hoy · '), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('18:48'), findsOneWidget);
      expect(find.text('Salida'), findsNothing);
      expect(find.text('Frenadas'), findsNWidgets(2));
    });

    test('el listado trae el DriveScore sin las categorías', () {
      final json = {
        'id': 3,
        'fecha_inicio': '2026-10-04T16:05:00Z',
        'fecha_fin': '2026-10-04T16:23:00Z',
        'distancia_m': 7400,
        'duracion_s': 1112,
        'velocidad_maxima_kmh': 62,
        'velocidad_promedio_kmh': 24,
        'drivescore': 86,
      };
      final viaje = RecorridoHistorial.fromJson(json);
      expect(viaje.drivescore, 86);
      expect(viaje.puntaje, isNull);
      expect(
        RecorridoHistorial.fromJson({...json, 'drivescore': null}).drivescore,
        isNull,
      );
    });

    test('lee los eventos por tipo del detalle', () {
      final json = {
        'id': 3,
        'fecha_inicio': '2026-10-04T16:05:00Z',
        'fecha_fin': '2026-10-04T16:23:00Z',
        'distancia_m': 7400,
        'duracion_s': 1112,
        'velocidad_maxima_kmh': 62,
        'velocidad_promedio_kmh': 24,
        'drivescore': 86,
        'puntaje_frenadas': 70,
        'puntaje_aceleraciones': 100,
        'puntaje_giros': 76,
        'puntaje_velocidad': 100,
        'eventos_por_tipo': {
          'frenada_brusca': 1,
          'aceleracion_severa': 0,
          'giro_agresivo': 1,
          'exceso_velocidad': 0,
        },
      };
      expect(
        RecorridoHistorial.fromJson(json).eventosPorTipo,
        _conteo(frenadas: 1, giros: 1),
      );
      // Viaje anterior a HU-15
      final antiguo = RecorridoHistorial.fromJson({
        ...json,
        'drivescore': null,
        'eventos_por_tipo': null,
      });
      expect(antiguo.puntaje, isNull);
      expect(antiguo.eventosPorTipo, isNull);
      expect(antiguo.eventos, isNull);
      expect(antiguo.ruta, isNull);
    });

    test('lee la ruta y los eventos con su posición (HU-29)', () {
      final viaje = RecorridoHistorial.fromJson({
        'id': 3,
        'fecha_inicio': '2026-10-04T16:05:00Z',
        'fecha_fin': '2026-10-04T16:23:00Z',
        'distancia_m': 7400,
        'duracion_s': 1112,
        'velocidad_maxima_kmh': 68,
        'velocidad_promedio_kmh': 24,
        'drivescore': 86,
        'ruta': [
          {
            'lat': -17.78,
            'lon': -63.18,
            'fecha': '2026-10-04T16:05:00Z',
            'velocidad_kmh': 0,
          },
          {
            'lat': -17.79,
            'lon': -63.19,
            'fecha': '2026-10-04T16:06:00Z',
            'velocidad_kmh': 30,
          },
        ],
        'eventos': [
          {
            'tipo': 'exceso_velocidad',
            'fecha': '2026-10-04T16:15:00Z',
            'lat': -17.785,
            'lon': -63.185,
            'velocidad_kmh': 61.2,
            'intensidad': 2.2,
            'duracion_s': 9,
            'velocidad_maxima_kmh': 68.4,
          },
        ],
      });
      expect(viaje.ruta, hasLength(2));
      expect(viaje.ruta!.last.longitud, -63.19);
      final exceso = viaje.eventos!.single;
      expect(exceso.tipo, TipoEvento.excesoVelocidad);
      expect((exceso.latitud, exceso.longitud), (-17.785, -63.185));
      expect(exceso.velocidadMaximaMs! * 3.6, closeTo(68.4, 1e-9));
      expect(exceso.duracionS, 9);
    });

    testWidgets('un viaje que no es del historial muestra el error', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso(
        paginas: (_) => _vacia(),
        detalle: (_) => throw const ErrorApi(
          mensaje: 'Recorrido no encontrado',
          codigo: 404,
        ),
      );
      await _mostrar(
        tester,
        const DetalleViajePantalla(recorridoId: 99),
        repositorio,
      );

      expect(find.text('Recorrido no encontrado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
