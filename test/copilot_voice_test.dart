import 'package:dio/dio.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/navegacion/data/navigation_repository.dart';
import 'package:drivesense/features/navegacion/models/route_plan.dart';
import 'package:drivesense/features/navegacion/models/route_progress.dart';
import 'package:drivesense/features/navegacion/models/voice_guide.dart';
import 'package:drivesense/features/navegacion/presentation/copilot_trip_view.dart';
import 'package:drivesense/features/navegacion/providers/copilot_provider.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
import 'package:drivesense/features/telemetria/data/voice_service.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/learning_coach.dart';
import 'package:drivesense/features/telemetria/presentation/widgets/learning_toggle.dart';
import 'package:drivesense/features/telemetria/providers/learning_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Ruta de prueba ------------------------------------------------------------
//
// Recta hacia el norte desde (-17.80, -63.18), un punto cada 0,001° (~111 m):
// 10 puntos, ~1 km. Gira a la derecha en el punto 5 (~555 m) y llega en el 9.

const _latInicio = -17.80;
const _lon = -63.18;
const _paso = 0.001;
final _metrosPorPaso = AcumuladorRecorrido.distanciaCoordenadas(
  _latInicio,
  _lon,
  _latInicio + _paso,
  _lon,
);

Coordenada _en(double metros) =>
    Coordenada(_latInicio + _paso * metros / _metrosPorPaso, _lon);

RutaPlaneada _ruta({int? salidaRotonda}) => RutaPlaneada(
  distanciaM: _metrosPorPaso * 9,
  duracionS: 180,
  trazado: [
    for (var i = 0; i < 10; i++) Coordenada(_latInicio + _paso * i, _lon),
  ],
  pasos: [
    const PasoRuta(
      instruccion: 'Diríjase al norte',
      tipo: TipoPaso.salida,
      distanciaM: 555,
      duracionS: 60,
      calle: 'Calle Junín',
      inicio: 0,
      fin: 5,
    ),
    PasoRuta(
      instruccion: 'Gire a la derecha',
      tipo: salidaRotonda == null
          ? TipoPaso.girarDerecha
          : TipoPaso.entrarRotonda,
      distanciaM: 444,
      duracionS: 100,
      calle: 'Avenida Busch',
      salidaRotonda: salidaRotonda,
      inicio: 5,
      fin: 9,
    ),
    const PasoRuta(
      instruccion: 'Llegada',
      tipo: TipoPaso.llegada,
      distanciaM: 0,
      duracionS: 0,
      inicio: 9,
      fin: 9,
    ),
  ],
);

final _t0 = DateTime(2026, 11, 19, 10);
DateTime _seg(int s) => _t0.add(Duration(seconds: s));

EventoRiesgo _evento(TipoEvento tipo, {bool enCurso = false}) => EventoRiesgo(
  tipo: tipo,
  fecha: _t0,
  intensidad: 3,
  latitud: _latInicio,
  longitud: _lon,
  velocidadPreviaMs: 10,
  velocidadMaximaMs: tipo == TipoEvento.excesoVelocidad ? 18 : null,
  duracionS: tipo == TipoEvento.excesoVelocidad ? 6 : null,
  enCurso: enCurso,
);

// --- Falsos ------------------------------------------------------------------

class _VozFalsa extends VozCopiloto {
  final dichos = <String>[];
  var calladas = 0;

  @override
  Future<void> hablar(String texto, {bool prioridad = false}) async =>
      dichos.add(texto);

  @override
  Future<void> callar() async => calladas++;
}

class _NavegacionFalsa extends NavegacionRepositorio {
  _NavegacionFalsa() : super(Dio());

  Future<RutaPlaneada> Function() respuesta = () async => _ruta();
  var pedidos = 0;

  @override
  Future<RutaPlaneada> ruta(Coordenada origen, Coordenada destino) {
    pedidos++;
    return respuesta();
  }
}

class _AprendizajeFijo extends ModoAprendizajeNotifier {
  _AprendizajeFijo(this.valor);

  final bool valor;

  @override
  Future<bool> build() async => valor;

  @override
  Future<void> cambiar(bool activo) async => state = AsyncData(activo);
}

class _SesionFija extends SesionNotifier {
  @override
  Future<Usuario?> build() async => const Usuario(
    id: 1,
    nombre: 'Ana Pérez',
    email: 'ana@prueba.com',
    telefono: '70000001',
    rol: 'conductor',
    debeCambiarContrasenia: false,
  );
}

const _destino = Destino(
  nombre: 'Cristo Redentor',
  posicion: Coordenada(-17.791, -63.18),
);

ViajeActivo _viajeActivo({Destino? destino = _destino}) => ViajeActivo(
  recorridoId: 7,
  fechaInicioServidor: _t0,
  acumulador: AcumuladorRecorrido(inicio: _t0),
  destino: destino,
);

Lectura _lectura(Coordenada c, {double precision = 5}) => Lectura(
  latitud: c.latitud,
  longitud: c.longitud,
  precisionM: precision,
  velocidadMs: 10,
  fecha: _t0,
);

/// Contenedor con voz y navegación falsas y el Modo aprendizaje en [aprendizaje].
Future<(ProviderContainer, CopilotoNotifier, _VozFalsa, _NavegacionFalsa)>
_copiloto({bool aprendizaje = false}) async {
  final voz = _VozFalsa();
  final navegacion = _NavegacionFalsa();
  final contenedor = ProviderContainer(
    overrides: [
      sesionProvider.overrideWith(_SesionFija.new),
      vozCopilotoProvider.overrideWithValue(voz),
      navegacionRepositorioProvider.overrideWithValue(navegacion),
      modoAprendizajeProvider.overrideWith(() => _AprendizajeFijo(aprendizaje)),
    ],
  );
  addTearDown(contenedor.dispose);
  await contenedor.read(modoAprendizajeProvider.future);
  final copiloto = contenedor.read(copilotoProvider.notifier);
  return (contenedor, copiloto, voz, navegacion);
}

void main() {
  group('Seguimiento sobre la ruta', () {
    test('proyecta la posición y calcula lo que falta', () {
      final seguidor = SeguidorRuta(_ruta());
      // 20 m al este de la ruta, a ~300 m del inicio
      final p = seguidor.actualizar(
        Coordenada(_en(300).latitud, _lon + 0.00019),
      );
      expect(p.distanciaARutaM, closeTo(20, 2));
      expect(p.recorridoM, closeTo(300, 2));
      expect(p.faltanM, closeTo(_metrosPorPaso * 9 - 300, 2));
      expect(p.faltanS, closeTo(180 * p.faltanM / (_metrosPorPaso * 9), 0.5));
      expect(p.proxima!.tipo, TipoPaso.girarDerecha);
      expect(p.hastaProximaM, closeTo(_metrosPorPaso * 5 - 300, 2));
    });

    test('pasado el giro, la próxima es la llegada', () {
      final seguidor = SeguidorRuta(_ruta());
      seguidor.actualizar(_en(300));
      final p = seguidor.actualizar(_en(700));
      expect(p.indicePaso, 1);
      expect(p.proxima!.tipo, TipoPaso.llegada);
      expect(p.llego, isFalse);
      expect(seguidor.actualizar(_en(_metrosPorPaso * 9 - 10)).llego, isTrue);
    });

    test('desvío: más de 50 m durante 5 s, solo con lecturas precisas', () {
      final desvio = DetectorDesvio();
      bool evaluar(double m, int s, {double precision = 5}) => desvio.evaluar(
        distanciaARutaM: m,
        precisionM: precision,
        ahora: _seg(s),
      );
      expect(evaluar(60, 0), isFalse);
      expect(evaluar(60, 4), isFalse);
      // Una lectura imprecisa no cuenta ni reinicia
      expect(evaluar(5, 4, precision: 30), isFalse);
      expect(evaluar(60, 5), isTrue);
      // De vuelta en la ruta
      expect(evaluar(10, 6), isFalse);
      expect(evaluar(60, 7), isFalse);
    });
  });

  group('Guía por voz', () {
    test('avisa a 300, 100 y 30 m, una vez cada uno', () {
      final seguidor = SeguidorRuta(_ruta());
      final guia = GuiaVoz();
      String? en(double m) =>
          guia.evaluar(seguidor.actualizar(_en(m)), seguidor);

      expect(en(100), isNull); // a ~455 m del giro
      expect(en(260), 'En 300 metros, gira a la derecha en Avenida Busch.');
      expect(en(270), isNull);
      expect(en(460), 'En 100 metros, gira a la derecha en Avenida Busch.');
      expect(en(470), isNull);
      expect(en(535), 'Ahora, gira a la derecha en Avenida Busch.');
      expect(en(545), isNull);
    });

    test('tramo corto: sin el aviso de 300 m', () {
      final ruta = _ruta();
      final corta = RutaPlaneada(
        distanciaM: ruta.distanciaM,
        duracionS: ruta.duracionS,
        trazado: ruta.trazado,
        pasos: [
          ruta.pasos[0],
          PasoRuta(
            instruccion: 'Gire',
            tipo: TipoPaso.girarIzquierda,
            distanciaM: 0,
            duracionS: 0,
            inicio: 3,
            fin: 9,
          ),
          ruta.pasos[2],
        ],
      );
      final seguidor = SeguidorRuta(corta);
      final guia = GuiaVoz();
      // El giro está a ~333 m del inicio: el tramo no llega a 400 m
      expect(guia.evaluar(seguidor.actualizar(_en(80)), seguidor), isNull);
      expect(
        guia.evaluar(seguidor.actualizar(_en(240)), seguidor),
        'En 90 metros, gira a la izquierda.',
      );
    });

    test('un aviso cercano deja sin efecto los lejanos', () {
      final seguidor = SeguidorRuta(_ruta());
      final guia = GuiaVoz();
      // Aparece directamente a 20 m del giro (p. ej. tras recalcular)
      expect(
        guia.evaluar(seguidor.actualizar(_en(535)), seguidor),
        startsWith('Ahora'),
      );
      expect(guia.evaluar(seguidor.actualizar(_en(540)), seguidor), isNull);
    });

    test('rotonda, llegada y nueva ruta', () {
      expect(
        GuiaVoz.maniobra(_ruta(salidaRotonda: 2).pasos[1]),
        'en la rotonda, toma la segunda salida',
      );
      expect(GuiaVoz.titulo(_ruta().pasos[1]), 'Gira a la derecha');
      expect(GuiaVoz.metrosHablados(87), '90 metros');
      expect(GuiaVoz.metrosHablados(1480), '1,5 kilómetros');

      final seguidor = SeguidorRuta(_ruta());
      final guia = GuiaVoz();
      seguidor.actualizar(_en(700));
      expect(
        guia.evaluar(
          seguidor.actualizar(_en(_metrosPorPaso * 9 - 10)),
          seguidor,
        ),
        FrasesCopiloto.llegada,
      );
      expect(guia.llegadaDicha, isTrue);
      expect(
        guia.evaluar(seguidor.actualizar(_en(_metrosPorPaso * 9)), seguidor),
        isNull,
      );
    });
  });

  group('Modo aprendizaje', () {
    test('el consejo de una maniobra va 3 s después', () {
      final consejero = ConsejeroAprendizaje()
        ..registrar(_evento(TipoEvento.frenadaBrusca), _seg(0));
      expect(consejero.revisar(_seg(1)), isNull);
      // Otra frenada: la maniobra sigue, la espera empieza de nuevo
      consejero.registrar(_evento(TipoEvento.frenadaBrusca), _seg(2));
      expect(consejero.revisar(_seg(4)), isNull);
      expect(consejero.revisar(_seg(5)), FrasesAprendizaje.frenada);
      expect(consejero.revisar(_seg(9)), isNull);
    });

    test('el exceso se aconseja al cerrarse', () {
      final consejero = ConsejeroAprendizaje()
        ..registrar(
          _evento(TipoEvento.excesoVelocidad, enCurso: true),
          _seg(0),
        );
      expect(consejero.revisar(_seg(10)), isNull);
      consejero.registrar(_evento(TipoEvento.excesoVelocidad), _seg(11));
      expect(consejero.revisar(_seg(11)), FrasesAprendizaje.exceso);
    });

    test('como mucho un consejo cada 15 s; el de en medio se descarta', () {
      final consejero = ConsejeroAprendizaje()
        ..registrar(_evento(TipoEvento.frenadaBrusca), _seg(0));
      expect(consejero.revisar(_seg(3)), FrasesAprendizaje.frenada);
      consejero.registrar(_evento(TipoEvento.aceleracionSevera), _seg(5));
      expect(consejero.revisar(_seg(8)), isNull);
      // No quedó encolado
      expect(consejero.revisar(_seg(20)), isNull);
      consejero.registrar(_evento(TipoEvento.giroAgresivo), _seg(20));
      expect(consejero.revisar(_seg(23)), FrasesAprendizaje.giro);
    });

    test('la indicación de ruta tiene prioridad', () {
      final consejero = ConsejeroAprendizaje()
        ..registrar(_evento(TipoEvento.frenadaBrusca), _seg(0))
        ..indicacionDicha(_seg(2));
      expect(consejero.revisar(_seg(3)), isNull);
    });

    test('giro con velocidad alta: una vez por maniobra', () {
      final seguidor = SeguidorRuta(_ruta());
      final consejero = ConsejeroAprendizaje();
      String? a(double metros, double kmh, int s) => consejero.acercamiento(
        progreso: seguidor.actualizar(_en(metros)),
        velocidadKmh: kmh,
        ahora: _seg(s),
      );
      // Lejos del giro, o despacio: nada
      expect(a(300, 55, 0), isNull);
      expect(a(450, 30, 1), isNull);
      expect(a(450, 45, 2), FrasesAprendizaje.giroConVelocidad);
      expect(a(480, 50, 20), isNull);
    });

    test('un giro leve no cuenta', () {
      expect(tiposGiro.contains(TipoPaso.girarLeveDerecha), isFalse);
      expect(tiposGiro.contains(TipoPaso.seguirRecto), isFalse);
      expect(tiposGiro.contains(TipoPaso.girarDerecha), isTrue);
    });
  });

  group('Copiloto en el viaje', () {
    test('guía por voz con la ruta del Copiloto', () async {
      final (_, copiloto, voz, navegacion) = await _copiloto();
      copiloto.comenzar(_viajeActivo(), ruta: _ruta());
      for (final m in <double>[100, 260, 460, 535, 700]) {
        copiloto.lectura(_lectura(_en(m)), velocidadKmh: 30);
      }
      expect(navegacion.pedidos, 0);
      expect(voz.dichos, [
        'En 300 metros, gira a la derecha en Avenida Busch.',
        'En 100 metros, gira a la derecha en Avenida Busch.',
        'Ahora, gira a la derecha en Avenida Busch.',
      ]);
      copiloto.lectura(_lectura(_en(_metrosPorPaso * 9 - 5)), velocidadKmh: 10);
      expect(voz.dichos.last, FrasesCopiloto.llegada);
      expect(copiloto.state!.llego, isTrue);
    });

    test('al continuar, pide la ruta con la primera lectura', () async {
      final (_, copiloto, _, navegacion) = await _copiloto();
      copiloto.comenzar(_viajeActivo());
      copiloto.lectura(_lectura(_en(50)), velocidadKmh: 20);
      await Future<void>.delayed(Duration.zero);
      expect(navegacion.pedidos, 1);
      expect(copiloto.state!.ruta, isNotNull);
    });

    test('desvío: lo dice, recalcula y avisa la ruta nueva', () async {
      final (_, copiloto, voz, navegacion) = await _copiloto();
      var ahora = _t0;
      copiloto
        ..reloj = (() => ahora)
        ..comenzar(_viajeActivo(), ruta: _ruta());
      final lejos = Coordenada(_en(200).latitud, _lon + 0.001); // ~105 m
      for (var s = 0; s <= 5; s++) {
        ahora = _seg(s);
        copiloto.lectura(_lectura(lejos), velocidadKmh: 30);
      }
      await Future<void>.delayed(Duration.zero);
      expect(voz.dichos, [
        FrasesCopiloto.desvio,
        FrasesCopiloto.rutaActualizada,
      ]);
      expect(navegacion.pedidos, 1);
    });

    test('sin conexión: sigue con la ruta y avisa una vez', () async {
      final (_, copiloto, voz, navegacion) = await _copiloto();
      navegacion.respuesta = () async => throw const ErrorNavegacion(
        MotivoErrorNavegacion.sinConexion,
        'Sin conexión',
      );
      var ahora = _t0;
      copiloto
        ..reloj = (() => ahora)
        ..comenzar(_viajeActivo(), ruta: _ruta());
      final lejos = Coordenada(_en(200).latitud, _lon + 0.001);
      for (var s = 0; s <= 30; s++) {
        ahora = _seg(s);
        copiloto.lectura(_lectura(lejos), velocidadKmh: 30);
        await Future<void>.delayed(Duration.zero);
      }
      // Recalcula como mucho cada 20 s y avisa una sola vez
      expect(navegacion.pedidos, 2);
      expect(
        voz.dichos.where((d) => d == FrasesCopiloto.sinConexionRecalcular),
        hasLength(1),
      );
      expect(copiloto.state!.sinConexion, isTrue);
      expect(copiloto.state!.ruta, isNotNull);
    });

    test('silenciado no habla y corta lo que decía', () async {
      final (_, copiloto, voz, _) = await _copiloto();
      copiloto
        ..comenzar(_viajeActivo(), ruta: _ruta())
        ..silenciar(true);
      expect(voz.calladas, 1);
      copiloto.lectura(_lectura(_en(260)), velocidadKmh: 30);
      expect(voz.dichos, isEmpty);
    });

    test('Modo aprendizaje en un viaje libre', () async {
      final (_, copiloto, voz, _) = await _copiloto(aprendizaje: true);
      var ahora = _t0;
      copiloto
        ..reloj = (() => ahora)
        ..comenzar(_viajeActivo(destino: null))
        ..evento(_evento(TipoEvento.aceleracionSevera));
      ahora = _seg(3);
      copiloto.segundo();
      expect(voz.dichos, [FrasesAprendizaje.aceleracion]);
    });

    test('sin Modo aprendizaje no da consejos', () async {
      final (_, copiloto, voz, _) = await _copiloto();
      var ahora = _t0;
      copiloto
        ..reloj = (() => ahora)
        ..comenzar(_viajeActivo(destino: null))
        ..evento(_evento(TipoEvento.aceleracionSevera));
      ahora = _seg(3);
      copiloto.segundo();
      expect(voz.dichos, isEmpty);
    });
  });

  group('Destino del viaje en curso', () {
    test('se guarda y se lee con el viaje', () {
      final viaje = _viajeActivo(
        destino: const Destino(
          nombre: 'Cristo Redentor',
          direccion: 'Santa Cruz, Bolivia',
          posicion: Coordenada(-17.7676, -63.1975),
        ),
      );
      final leido = ViajeActivo.fromJson(viaje.toJson());
      expect(leido.destino!.nombre, 'Cristo Redentor');
      expect(leido.destino!.direccion, 'Santa Cruz, Bolivia');
      // Un viaje guardado antes de HU-31 sigue siendo libre
      final anterior = viaje.toJson()..remove('destino');
      expect(ViajeActivo.fromJson(anterior).destino, isNull);
    });

    test('/activo trae el destino', () {
      final recorrido = Recorrido.fromJson({
        'id': 7,
        'estado': 'en_curso',
        'fecha_inicio': '2026-11-19T14:00:00Z',
        'destino': {'nombre': 'Cristo Redentor', 'lat': -17.7, 'lon': -63.2},
      });
      expect(recorrido.destino!.nombre, 'Cristo Redentor');
    });
  });

  group('Pantalla del viaje con Copiloto', () {
    Future<void> mostrar(WidgetTester tester, EstadoCopiloto estado) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final viaje = _viajeActivo()..acumulador.agregar(_lectura(_en(300)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            copilotoProvider.overrideWith(() => _CopilotoFijo(estado)),
            modoAprendizajeProvider.overrideWith(() => _AprendizajeFijo(false)),
          ],
          child: MaterialApp(
            theme: temaClaro(),
            home: Scaffold(
              body: VistaViajeCopiloto(
                viaje: ViajeEnCurso(viaje: viaje, ahora: _t0),
                alVolver: () {},
                alFinalizar: () {},
                finalizando: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('próxima maniobra, lo que falta y la siguiente', (
      tester,
    ) async {
      final seguidor = SeguidorRuta(_ruta());
      await mostrar(
        tester,
        EstadoCopiloto(
          destino: _destino,
          ruta: _ruta(),
          progreso: seguidor.actualizar(_en(435)),
        ),
      );
      expect(find.text('Gira a la derecha'), findsOneWidget);
      expect(find.text('Avenida Busch'), findsOneWidget);
      expect(find.text('120 m'), findsOneWidget);
      expect(find.textContaining('Faltan'), findsOneWidget);
      expect(find.text('Copiloto'), findsOneWidget);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      expect(find.byTooltip('Silenciar la voz'), findsOneWidget);
      expect(find.byTooltip('Modo aprendizaje'), findsOneWidget);
    });

    testWidgets('recalculando', (tester) async {
      await mostrar(
        tester,
        const EstadoCopiloto(destino: _destino, recalculando: true),
      );
      expect(find.text('Recalculando…'), findsOneWidget);
      expect(find.text('Calculando la ruta…'), findsOneWidget);
    });

    testWidgets('llegada', (tester) async {
      await mostrar(
        tester,
        const EstadoCopiloto(destino: _destino, llego: true),
      );
      expect(find.text('Llegaste a tu destino'), findsOneWidget);
    });

    testWidgets('silenciado: el botón ofrece activar la voz', (tester) async {
      await mostrar(
        tester,
        const EstadoCopiloto(destino: _destino, silenciado: true),
      );
      expect(find.byTooltip('Activar la voz'), findsOneWidget);
    });
  });

  testWidgets('interruptor del Modo aprendizaje', (tester) async {
    final contenedor = ProviderContainer(
      overrides: [
        modoAprendizajeProvider.overrideWith(() => _AprendizajeFijo(false)),
      ],
    );
    addTearDown(contenedor.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: contenedor,
        child: MaterialApp(
          theme: temaClaro(),
          home: const Scaffold(body: TarjetaAprendizaje()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Modo aprendizaje'), findsOneWidget);
    expect(find.text('Silenciar voz'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(contenedor.read(modoAprendizajeProvider).value, isTrue);
    expect(find.text('Silenciar voz'), findsOneWidget);
  });
}

class _CopilotoFijo extends CopilotoNotifier {
  _CopilotoFijo(this.estado);

  final EstadoCopiloto estado;

  @override
  EstadoCopiloto? build() => estado;

  @override
  void silenciar(bool silenciado) =>
      state = state?.copyWith(silenciado: silenciado);
}
