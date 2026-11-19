import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drivesense/app/router.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/navegacion/data/navigation_repository.dart';
import 'package:drivesense/features/navegacion/models/route_plan.dart';
import 'package:drivesense/features/navegacion/presentation/copilot_screen.dart';
import 'package:drivesense/features/navegacion/presentation/route_format.dart';
import 'package:drivesense/features/navegacion/presentation/widgets/trip_type_sheet.dart';
import 'package:drivesense/features/recorridos/data/location_service.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/presentation/widgets/trip_map.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// --- Datos -----------------------------------------------------------------

const _usuario = Usuario(
  id: 1,
  nombre: 'Ana Pérez',
  email: 'ana@prueba.com',
  telefono: '70000001',
  rol: 'conductor',
  debeCambiarContrasenia: false,
);

const _ubicacion = Coordenada(-17.7834, -63.1821);
const _cristo = Lugar(
  nombre: 'Cristo Redentor',
  direccion: 'Cristo Redentor, Santa Cruz de la Sierra, Santa Cruz, Bolivia',
  posicion: Coordenada(-17.7676, -63.1975),
);

final _jsonRuta = <String, dynamic>{
  'distancia_m': 3120.4,
  'duracion_s': 410.2,
  'trazado': [
    {'lat': -17.7834, 'lon': -63.1821},
    {'lat': -17.78, 'lon': -63.183},
    {'lat': -17.7676, 'lon': -63.1975},
  ],
  'pasos': [
    {
      'instruccion': 'Diríjase al norte por Calle Junín',
      'tipo': 'salida',
      'calle': 'Calle Junín',
      'distancia_m': 200.0,
      'duracion_s': 30.0,
      'salida_rotonda': null,
      'inicio': 0,
      'fin': 1,
    },
    {
      'instruccion': 'Entre en la rotonda y tome la 2.ª salida',
      'tipo': 'entrar_rotonda',
      'calle': null,
      'distancia_m': 2920.4,
      'duracion_s': 380.2,
      'salida_rotonda': 2,
      'inicio': 1,
      'fin': 2,
    },
    {
      'instruccion': 'Llegada a su destino',
      'tipo': 'llegada',
      'calle': null,
      'distancia_m': 0.0,
      'duracion_s': 0.0,
      'salida_rotonda': null,
      'inicio': 2,
      'fin': 2,
    },
  ],
};

// --- Falsos ------------------------------------------------------------------

class _SesionFija extends SesionNotifier {
  @override
  Future<Usuario?> build() async => _usuario;
}

/// Registra con qué destino se inició el viaje, sin GPS ni backend.
class _ViajeFalso extends ViajeNotifier {
  static final iniciados = <Destino?>[];

  @override
  Future<EstadoViaje> build() async => const SinViaje();

  @override
  Future<void> iniciar({Destino? destino, RutaPlaneada? ruta}) async =>
      iniciados.add(destino);
}

class _UbicacionFalsa extends ServicioUbicacion {
  @override
  Future<bool> permisosConcedidos() async => true;

  @override
  Future<EstadoUbicacion> preparar() async => EstadoUbicacion.lista;

  @override
  Future<Lectura> posicionActual() async => Lectura(
    latitud: _ubicacion.latitud,
    longitud: _ubicacion.longitud,
    precisionM: 5,
    velocidadMs: 0,
    fecha: DateTime.now(),
  );
}

class _NavegacionFalsa extends NavegacionRepositorio {
  _NavegacionFalsa() : super(Dio());

  Future<RutaPlaneada> Function(Coordenada destino) rutaDe = (_) async =>
      RutaPlaneada.fromJson(_jsonRuta);
  Future<List<Lugar>> Function(String texto) lugaresDe = (_) async => [_cristo];
  final destinosPedidos = <Coordenada>[];
  final busquedas = <String>[];

  @override
  Future<RutaPlaneada> ruta(Coordenada origen, Coordenada destino) {
    destinosPedidos.add(destino);
    return rutaDe(destino);
  }

  @override
  Future<List<Lugar>> lugares(String texto) {
    busquedas.add(texto);
    return lugaresDe(texto);
  }
}

/// Responde siempre lo mismo, sin red.
class _AdaptadorFijo implements HttpClientAdapter {
  _AdaptadorFijo(this.codigo, [this.cuerpo]);

  final int codigo;
  final Map<String, dynamic>? cuerpo;
  RequestOptions? ultimaPeticion;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaPeticion = options;
    return ResponseBody.fromString(
      cuerpo == null ? '' : jsonEncode(cuerpo),
      codigo,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Inicio con un botón que abre el Copiloto, y la pantalla en vivo.
Future<_NavegacionFalsa> _mostrarCopiloto(
  WidgetTester tester, {
  _NavegacionFalsa? navegacion,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  _ViajeFalso.iniciados.clear();
  final repositorio = navegacion ?? _NavegacionFalsa();

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (contexto, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => contexto.push(Rutas.copiloto),
              child: const Text('Abrir copiloto'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Rutas.copiloto,
        builder: (_, _) => const CopilotoPantalla(),
      ),
      GoRoute(
        path: Rutas.recorrido,
        builder: (_, _) => const Scaffold(body: Text('Viaje en vivo')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        viajeProvider.overrideWith(_ViajeFalso.new),
        servicioUbicacionProvider.overrideWithValue(_UbicacionFalsa()),
        navegacionRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp.router(theme: temaClaro(), routerConfig: router),
    ),
  );
  await tester.tap(find.text('Abrir copiloto'));
  await tester.pumpAndSettle();
  return repositorio;
}

Future<void> _elegirCristoBuscando(WidgetTester tester) async {
  await tester.tap(find.text('Buscar destino'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'cristo');
  await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_cristo.direccion));
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('lee la ruta con sus pasos', () {
      final ruta = RutaPlaneada.fromJson(_jsonRuta);
      expect(ruta.distanciaM, 3120.4);
      expect(ruta.trazado.first, _ubicacion);
      expect(ruta.pasos.map((p) => p.tipo), [
        TipoPaso.salida,
        TipoPaso.entrarRotonda,
        TipoPaso.llegada,
      ]);
      expect(ruta.pasos[1].salidaRotonda, 2);
      expect(ruta.pasos[1].calle, isNull);
    });

    test('un tipo de paso desconocido es seguir recto', () {
      expect(TipoPaso.desdeCodigo('volar'), TipoPaso.seguirRecto);
    });

    test('destino del detalle y del POST', () {
      expect(Destino.fromJson(null), isNull);
      final destino = Destino.fromJson({
        'nombre': 'Cristo Redentor',
        'lat': -17.7676,
        'lon': -63.1975,
      })!;
      expect(destino.nombre, 'Cristo Redentor');
      expect(destino.posicion, const Coordenada(-17.7676, -63.1975));

      final enMapa = Destino.enMapa(_ubicacion);
      expect(enMapa.nombre, 'Punto en el mapa');
      expect(enMapa.esPuntoEnMapa, isTrue);
      expect(enMapa.toApiJson(), {
        'nombre': 'Punto en el mapa',
        'lat': -17.7834,
        'lon': -63.1821,
      });
      final largo = Destino(nombre: 'x' * 200, posicion: _ubicacion);
      expect((largo.toApiJson()['nombre'] as String).length, 150);
    });

    test('formatos de distancia y tiempo', () {
      expect(FormatoRuta.distancia(204), '200 m');
      expect(FormatoRuta.distancia(3120.4), '3,12 km');
      expect(FormatoRuta.duracion(410), '7 min');
      expect(FormatoRuta.duracion(20), '1 min');
      expect(FormatoRuta.duracion(3900), '1 h 05 min');
    });
  });

  group('Repositorio', () {
    test('pide la ruta con origen y destino', () async {
      final adaptador = _AdaptadorFijo(200, _jsonRuta);
      final repositorio = NavegacionRepositorio(
        Dio()..httpClientAdapter = adaptador,
      );
      final ruta = await repositorio.ruta(_ubicacion, _cristo.posicion);
      expect(ruta.pasos, hasLength(3));
      expect(adaptador.ultimaPeticion!.path, '/navegacion/ruta');
      expect(adaptador.ultimaPeticion!.queryParameters, {
        'origen_lat': -17.7834,
        'origen_lon': -63.1821,
        'destino_lat': -17.7676,
        'destino_lon': -63.1975,
      });
    });

    test('lee los lugares', () async {
      final adaptador = _AdaptadorFijo(200, {
        'lugares': [
          {
            'nombre': 'Cristo Redentor',
            'direccion': 'Santa Cruz, Bolivia',
            'lat': -17.7676,
            'lon': -63.1975,
          },
        ],
      });
      final repositorio = NavegacionRepositorio(
        Dio()..httpClientAdapter = adaptador,
      );
      final lugares = await repositorio.lugares('  cristo ');
      expect(lugares.single.nombre, 'Cristo Redentor');
      expect(adaptador.ultimaPeticion!.queryParameters, {'q': 'cristo'});
    });

    for (final (codigo, clave, motivo) in [
      (404, 'sin_ruta', MotivoErrorNavegacion.sinRuta),
      (503, 'sin_cuota', MotivoErrorNavegacion.sinCuota),
      (503, 'navegacion_desactivada', MotivoErrorNavegacion.noDisponible),
      (503, 'proveedor_caido', MotivoErrorNavegacion.noDisponible),
    ]) {
      test('error $clave', () async {
        final repositorio = NavegacionRepositorio(
          Dio()
            ..httpClientAdapter = _AdaptadorFijo(codigo, {
              'detail': 'Mensaje del backend',
              'codigo': clave,
            }),
        );
        await expectLater(
          repositorio.ruta(_ubicacion, _cristo.posicion),
          throwsA(
            isA<ErrorNavegacion>()
                .having((e) => e.motivo, 'motivo', motivo)
                .having((e) => e.mensaje, 'mensaje', 'Mensaje del backend'),
          ),
        );
      });
    }

    test('sin conexión o 5xx sin código', () {
      expect(
        traducirError(const ErrorApi(mensaje: ErrorApi.sinConexion)),
        isA<ErrorNavegacion>().having(
          (e) => e.motivo,
          'motivo',
          MotivoErrorNavegacion.sinConexion,
        ),
      );
      expect(
        traducirError(const ErrorApi(mensaje: 'x', codigo: 502)),
        isA<ErrorNavegacion>(),
      );
    });

    test('401 y 422 siguen como ErrorApi', () {
      expect(
        traducirError(const ErrorApi(mensaje: 'x', codigo: 401)),
        isA<ErrorApi>(),
      );
      expect(
        traducirError(const ErrorApi(mensaje: 'x', codigo: 422)),
        isA<ErrorApi>(),
      );
    });
  });

  group('Elegir tipo de recorrido', () {
    testWidgets('hoja con las dos opciones', (tester) async {
      TipoRecorrido? elegido;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(),
          home: Builder(
            builder: (contexto) => TextButton(
              onPressed: () async {
                elegido = await showModalBottomSheet<TipoRecorrido>(
                  context: contexto,
                  builder: (_) => const HojaTipoRecorrido(),
                );
              },
              child: const Text('Iniciar'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo quieres viajar?'), findsOneWidget);
      expect(find.text('Recorrido libre'), findsOneWidget);
      expect(find.text('COPILOTO'), findsOneWidget);

      await tester.tap(find.text('Con destino'));
      await tester.pumpAndSettle();
      expect(elegido, TipoRecorrido.conDestino);
    });
  });

  group('Copiloto', () {
    testWidgets('sin destino: cómo elegirlo', (tester) async {
      await _mostrarCopiloto(tester);
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      expect(find.text('Buscar destino'), findsOneWidget);
      expect(find.text('Iniciar con destino'), findsNothing);
    });

    testWidgets('buscar un lugar muestra la ruta y sus pasos', (tester) async {
      final navegacion = await _mostrarCopiloto(tester);
      await _elegirCristoBuscando(tester);

      expect(navegacion.busquedas, ['cristo']);
      expect(navegacion.destinosPedidos, [_cristo.posicion]);
      expect(find.text('Cristo Redentor'), findsOneWidget);
      expect(find.text('3,12 km · 7 min'), findsOneWidget);

      await tester.tap(find.text('Ver pasos'));
      await tester.pumpAndSettle();
      expect(find.text('Pasos de la ruta'), findsOneWidget);
      expect(find.text('Diríjase al norte por Calle Junín'), findsOneWidget);
      expect(find.text('2,92 km'), findsOneWidget);
    });

    testWidgets('búsqueda corta: aviso sin consultar', (tester) async {
      final navegacion = await _mostrarCopiloto(tester);
      await tester.tap(find.text('Buscar destino'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe al menos 3 letras.'), findsOneWidget);
      expect(navegacion.busquedas, isEmpty);
    });

    testWidgets('búsqueda sin resultados', (tester) async {
      final navegacion = _NavegacionFalsa()..lugaresDe = (_) async => [];
      await _mostrarCopiloto(tester, navegacion: navegacion);
      await tester.tap(find.text('Buscar destino'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No encontramos lugares con ese nombre'),
        findsOneWidget,
      );
    });

    testWidgets('quitar el destino vuelve al inicio', (tester) async {
      await _mostrarCopiloto(tester);
      await _elegirCristoBuscando(tester);
      await tester.tap(find.byTooltip('Quitar destino'));
      await tester.pumpAndSettle();
      expect(find.text('¿A dónde vas?'), findsOneWidget);
    });

    testWidgets('iniciar con destino abre el viaje en vivo', (tester) async {
      await _mostrarCopiloto(tester);
      await _elegirCristoBuscando(tester);
      await tester.tap(find.text('Iniciar con destino'));
      await tester.pumpAndSettle();

      expect(find.text('Viaje en vivo'), findsOneWidget);
      final destino = _ViajeFalso.iniciados.single!;
      expect(destino.nombre, 'Cristo Redentor');
      expect(destino.posicion, _cristo.posicion);
    });

    testWidgets('sin ruta: aviso y recorrido libre', (tester) async {
      final navegacion = _NavegacionFalsa()
        ..rutaDe = (_) async => throw const ErrorNavegacion(
          MotivoErrorNavegacion.sinRuta,
          'No se encontró una ruta en auto hasta ese destino',
        );
      await _mostrarCopiloto(tester, navegacion: navegacion);
      await _elegirCristoBuscando(tester);

      expect(find.text('No encontramos una ruta'), findsOneWidget);
      // Reintentar no cambia nada sin ruta: solo se ofrece el recorrido libre
      expect(find.text('Reintentar'), findsNothing);
      await tester.tap(find.text('Recorrido libre'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje en vivo'), findsOneWidget);
      expect(_ViajeFalso.iniciados, [null]);
    });

    testWidgets('sin conexión: reintentar vuelve a pedir la ruta', (
      tester,
    ) async {
      var intentos = 0;
      final navegacion = _NavegacionFalsa()
        ..rutaDe = (_) async {
          intentos++;
          if (intentos == 1) {
            throw const ErrorNavegacion(
              MotivoErrorNavegacion.sinConexion,
              'Revisa tu conexión a internet e intenta de nuevo.',
            );
          }
          return RutaPlaneada.fromJson(_jsonRuta);
        };
      await _mostrarCopiloto(tester, navegacion: navegacion);
      await _elegirCristoBuscando(tester);

      expect(find.text('Sin conexión'), findsWidgets);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(intentos, 2);
      expect(find.text('Iniciar con destino'), findsOneWidget);
    });

    testWidgets('tocar el mapa elige un punto', (tester) async {
      Coordenada? elegido;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(),
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MapaDestino(
                ubicacion: _ubicacion,
                alElegirDestino: (punto) => elegido = punto,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(MapaDestino));
      await tester.pump(const Duration(milliseconds: 500));
      expect(elegido, isNotNull);
      // El centro del mapa es la ubicación
      expect(elegido!.latitud, closeTo(_ubicacion.latitud, 0.001));
      expect(elegido!.longitud, closeTo(_ubicacion.longitud, 0.001));
    });
  });
}
