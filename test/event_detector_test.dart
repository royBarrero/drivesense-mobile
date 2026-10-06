import 'dart:convert';
import 'dart:io';

import 'package:drivesense/features/recorridos/data/trip_local_storage.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/telemetria/data/sensor_service.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
import 'package:drivesense/features/telemetria/models/rate_limiter.dart';
import 'package:drivesense/features/telemetria/models/sensor_sample.dart';
import 'package:drivesense/features/telemetria/models/signal_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _inicio = DateTime.utc(2026, 10, 1, 12);
const _latitud = -17.78;
const _longitud = -63.18;

Lectura _lectura(DateTime fecha, double velocidadMs) => Lectura(
  latitud: _latitud,
  longitud: _longitud,
  precisionM: 5,
  velocidadMs: velocidadMs,
  fecha: fecha,
);

/// Filtro y detector juntos, como en `CapturaSensores` (con su
/// `LimitadorFrecuencia` a ~50 Hz).
class _Captura {
  final filtro = FiltroSenal();
  final detector = DetectorEventos();
  final eventos = <EventoRiesgo>[];
  final _limiteAcelerometro = LimitadorFrecuencia(CapturaSensores.periodo);
  final _limiteGiroscopio = LimitadorFrecuencia(CapturaSensores.periodo);

  _Captura() {
    detector.alDetectar = eventos.add;
  }

  void gps(Lectura lectura) {
    filtro.gps(lectura);
    detector.evaluar(filtro);
  }

  void acelerometro(MuestraSensor muestra) {
    if (_limiteAcelerometro.aceptar(muestra.fecha)) {
      filtro.acelerometro(muestra);
    }
  }

  void giroscopio(MuestraSensor muestra) {
    if (!_limiteGiroscopio.aceptar(muestra.fecha)) return;
    filtro.giroscopio(muestra);
    detector.evaluarGiro(filtro, muestra.fecha);
  }
}

/// Tramo de [segundos] a [velocidadMs] con el auto girando a [giroRadS].
typedef _Tramo = ({double segundos, double velocidadMs, double giroRadS});

_Tramo _recta(double segundos, [double velocidadMs = 10]) =>
    (segundos: segundos, velocidadMs: velocidadMs, giroRadS: 0);

_Tramo _curva(double segundos, double giroRadS, [double velocidadMs = 10]) =>
    (segundos: segundos, velocidadMs: velocidadMs, giroRadS: giroRadS);

/// Eventos al recorrer [tramos] con el teléfono plano: acelerómetro y
/// giroscopio a 50 Hz y una lectura del GPS por segundo (hasta [gpsHasta] s).
/// Con [golpeEn] (s), un golpe vertical de 0,2 s.
List<EventoRiesgo> _recorrer(
  List<_Tramo> tramos, {
  bool conGiroscopio = true,
  double? golpeEn,
  double? gpsHasta,
}) {
  final captura = _Captura();
  if (!conGiroscopio) captura.filtro.sinGiroscopio();
  var paso = 0;
  for (final tramo in tramos) {
    for (var i = 0; i < (tramo.segundos * 50).round(); i++) {
      paso++;
      final t = paso / 50;
      final fecha = _inicio.add(Duration(milliseconds: paso * 20));
      final golpe = golpeEn != null && t >= golpeEn && t < golpeEn + 0.2;
      captura.acelerometro(
        MuestraSensor(fecha: fecha, x: 0, y: 0, z: 9.81 + (golpe ? 8 : 0)),
      );
      if (conGiroscopio) {
        captura.giroscopio(
          MuestraSensor(fecha: fecha, x: 0, y: 0, z: tramo.giroRadS),
        );
      }
      if (paso % 50 == 0 && (gpsHasta == null || t <= gpsHasta)) {
        captura.gps(_lectura(fecha, tramo.velocidadMs));
      }
    }
  }
  return captura.eventos;
}

/// Eventos tras pasar [velocidades] (m/s); [segundos] da el instante de cada
/// lectura (por defecto, 1 por segundo).
List<EventoRiesgo> _eventos(List<double> velocidades, {List<int>? segundos}) {
  final captura = _Captura();
  for (var i = 0; i < velocidades.length; i++) {
    final segundo = segundos?[i] ?? i;
    captura.gps(
      _lectura(_inicio.add(Duration(seconds: segundo)), velocidades[i]),
    );
  }
  return captura.eventos;
}

/// 50 Hz de acelerómetro con el teléfono plano y una lectura del GPS por
/// segundo; con [golpeEn] (s), un golpe vertical de 0,2 s.
List<EventoRiesgo> _conSensores(List<double> velocidades, {double? golpeEn}) {
  final captura = _Captura();
  for (var s = 0; s < velocidades.length; s++) {
    for (var i = 1; i <= 50; i++) {
      final t = s - 1 + i / 50;
      final golpe = golpeEn != null && t >= golpeEn && t < golpeEn + 0.2;
      captura.filtro.acelerometro(
        MuestraSensor(
          fecha: _inicio.add(Duration(milliseconds: (t * 1000).round())),
          x: 0,
          y: 0,
          z: 9.81 + (golpe ? 8 : 0),
        ),
      );
    }
    captura.gps(_lectura(_inicio.add(Duration(seconds: s)), velocidades[s]));
  }
  return captura.eventos;
}

/// Reproduce un CSV de calibración (como lo graba la app): sensores y GPS,
/// este sin posición (se usa una fija).
List<EventoRiesgo> _reproducir(String archivo) {
  final captura = _Captura();
  final lineas = File('test/fixtures/$archivo').readAsLinesSync().skip(1);
  for (final linea in lineas) {
    final c = linea.split(',');
    final fecha = DateTime.fromMicrosecondsSinceEpoch(
      int.parse(c[1]),
      isUtc: true,
    );
    MuestraSensor muestra() => MuestraSensor(
      fecha: fecha,
      x: double.parse(c[2]),
      y: double.parse(c[3]),
      z: double.parse(c[4]),
    );
    switch (c[0]) {
      case 'acc':
        captura.acelerometro(muestra());
      case 'gir':
        captura.giroscopio(muestra());
      case 'gps':
        captura.gps(
          Lectura(
            latitud: _latitud,
            longitud: _longitud,
            precisionM: double.parse(c[7]),
            velocidadMs: double.parse(c[8]),
            fecha: fecha,
          ),
        );
    }
  }
  return captura.eventos;
}

/// Solo los eventos de [tipo].
List<EventoRiesgo> _de(TipoEvento tipo, List<EventoRiesgo> eventos) =>
    eventos.where((evento) => evento.tipo == tipo).toList();

/// La última versión de cada evento (mismo tipo y fecha), en el orden en
/// que aparecieron: el exceso de velocidad se avisa de nuevo mientras dura.
List<EventoRiesgo> _unicos(List<EventoRiesgo> avisos) {
  final porEvento = <(TipoEvento, DateTime), EventoRiesgo>{};
  for (final aviso in avisos) {
    porEvento[(aviso.tipo, aviso.fecha)] = aviso;
  }
  return porEvento.values.toList();
}

/// `SharedPreferencesAsync` en memoria, con lo que usa `AlmacenRecorrido`.
class _PreferenciasEnMemoria implements SharedPreferencesAsync {
  final _valores = <String, String>{};

  @override
  Future<String?> getString(String key) async => _valores[key];

  @override
  Future<void> setString(String key, String value) async =>
      _valores[key] = value;

  @override
  Future<void> remove(String key) async => _valores.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Frenada brusca', () {
    test('desde 3,0 m/s² es un evento; bajo el umbral, no', () {
      expect(_eventos([10, 10, 7, 7, 7]), hasLength(1));
      expect(_eventos([10, 10, 7.1, 7.1, 7.1]), isEmpty);
    });

    test('trae la intensidad, la velocidad previa y la posición', () {
      final evento = _eventos([10, 10, 6, 6, 6]).single;
      expect(evento.tipo, TipoEvento.frenadaBrusca);
      expect(evento.fecha, _inicio.add(const Duration(seconds: 2)));
      expect(evento.intensidad, closeTo(4, 1e-9));
      expect(evento.velocidadPreviaMs, 10);
      expect(evento.latitud, _latitud);
      expect(evento.longitud, _longitud);
    });

    test('una frenada sostenida es un solo evento', () {
      expect(_eventos([20, 20, 16, 12, 8, 4, 0, 0]), hasLength(1));
    });

    test('dos frenadas separadas por al menos 3 s son dos eventos', () {
      expect(_eventos([20, 16, 16, 16, 12, 12, 12]), hasLength(2));
    });

    test('a menos de 3 s de la anterior no se repite', () {
      expect(_eventos([20, 16, 15, 11, 11, 11]), hasLength(1));
    });

    test('tras un hueco de más de 3 s no se evalúa', () {
      expect(_eventos([10, 10, 0, 0, 0], segundos: [0, 1, 6, 7, 8]), isEmpty);
    });

    test('una caída de una sola lectura que el filtro quita no es evento', () {
      expect(_eventos([10, 10, 0, 10, 10]), isEmpty);
    });

    test('durante un bache no se evalúa', () {
      final velocidades = <double>[10, 10, 10, 10, 10, 10, 6, 6, 6];
      expect(_conSensores(velocidades), hasLength(1));
      expect(_conSensores(velocidades, golpeEn: 5.5), isEmpty);
    });
  });

  group('Aceleración severa', () {
    const acel = TipoEvento.aceleracionSevera;

    test('desde 2,5 m/s² es un evento; bajo el umbral, no', () {
      expect(_eventos([5, 5, 7.5, 7.5, 7.5]), hasLength(1));
      expect(_eventos([5, 5, 7.4, 7.4, 7.4]), isEmpty);
    });

    test('trae la intensidad, la velocidad previa y la posición', () {
      final evento = _eventos([5, 5, 9, 9, 9]).single;
      expect(evento.tipo, acel);
      expect(evento.fecha, _inicio.add(const Duration(seconds: 2)));
      expect(evento.intensidad, closeTo(4, 1e-9));
      expect(evento.velocidadPreviaMs, 5);
      expect(evento.latitud, _latitud);
      expect(evento.longitud, _longitud);
    });

    test('una aceleración sostenida es un solo evento', () {
      expect(_eventos([0, 0, 3, 6, 9, 12, 12]), hasLength(1));
    });

    test('dos aceleraciones separadas por al menos 3 s son dos eventos', () {
      expect(_eventos([0, 3, 3, 3, 6, 6, 6]), hasLength(2));
    });

    test('a menos de 3 s de la anterior no se repite', () {
      expect(_eventos([0, 3, 4, 7, 7, 7]), hasLength(1));
    });

    test('tras un hueco de más de 3 s no se evalúa', () {
      expect(_eventos([0, 0, 10, 10, 10], segundos: [0, 1, 6, 7, 8]), isEmpty);
    });

    test('un pico de una sola lectura que el filtro quita no es evento', () {
      expect(_eventos([10, 10, 15, 10, 10]), isEmpty);
    });

    test('durante un bache no se evalúa', () {
      final velocidades = <double>[5, 5, 5, 5, 5, 5, 9, 9, 9];
      expect(_conSensores(velocidades), hasLength(1));
      expect(_conSensores(velocidades, golpeEn: 5.5), isEmpty);
    });

    test('una frenada no bloquea la aceleración que sigue', () {
      final eventos = _eventos([10, 10, 6, 6, 10, 10]);
      expect(
        [for (final e in eventos) e.tipo],
        [TipoEvento.frenadaBrusca, acel],
      );
    });
  });

  group('Giro agresivo', () {
    const giro = TipoEvento.giroAgresivo;

    test('desde 3,5 m/s² de aceleración lateral es un evento', () {
      // A 10 m/s: 0,4 rad/s = 4 m/s²; 0,34 rad/s = 3,4 m/s²
      final eventos = _recorrer([_recta(5), _curva(2, 0.4), _recta(3)]);
      expect([for (final e in eventos) e.tipo], [giro]);
      expect(_recorrer([_recta(5), _curva(2, 0.34), _recta(3)]), isEmpty);
    });

    test('trae la intensidad, la velocidad y la posición', () {
      final evento = _recorrer([_recta(5), _curva(2, 0.4), _recta(3)]).single;
      // Se avisa al cruzar el umbral, mientras la media de 1 s sube
      expect(evento.intensidad, inInclusiveRange(3.5, 3.6));
      expect(evento.velocidadPreviaMs, 10);
      expect(evento.latitud, _latitud);
      expect(evento.longitud, _longitud);
      final inicioCurva = _inicio.add(const Duration(seconds: 5));
      expect(evento.fecha.isAfter(inicioCurva), isTrue);
    });

    test('a la derecha también, con intensidad positiva', () {
      final evento = _recorrer([_recta(5), _curva(2, -0.4), _recta(3)]).single;
      expect(evento.tipo, giro);
      expect(evento.intensidad, greaterThanOrEqualTo(3.5));
    });

    test('a 15 km/h o menos no se evalúa', () {
      // 3,9 m/s (14 km/h) × 1,2 rad/s = 4,7 m/s²
      expect(
        _recorrer([_recta(5, 3.9), _curva(2, 1.2, 3.9), _recta(3, 3.9)]),
        isEmpty,
      );
    });

    test('una curva sostenida es un solo evento', () {
      expect(_recorrer([_recta(5), _curva(6, 0.5), _recta(3)]), hasLength(1));
    });

    test('dos curvas separadas por una recta son dos eventos', () {
      expect(
        _recorrer([
          _recta(5),
          _curva(2, 0.5),
          _recta(4),
          _curva(2, 0.5),
          _recta(3),
        ]),
        hasLength(2),
      );
    });

    test('sin giroscopio no hay giros', () {
      expect(
        _recorrer([_recta(5), _curva(2, 0.5), _recta(3)], conGiroscopio: false),
        isEmpty,
      );
    });

    test('un bache en la curva la descarta', () {
      expect(
        _recorrer([_recta(5), _curva(2, 0.5), _recta(3)], golpeEn: 5.5),
        isEmpty,
      );
    });

    test('sin GPS hace más de 3 s no se evalúa', () {
      final tramos = [_recta(6), _curva(2, 0.5), _recta(3)];
      expect(_recorrer(tramos), hasLength(1));
      expect(_recorrer(tramos, gpsHasta: 3), isEmpty);
    });
  });

  group('Exceso de velocidad', () {
    const vel = TipoEvento.excesoVelocidad;
    // 60 km/h = 16,67 m/s; las lecturas se confirman con una de retraso, por
    // eso cada lista termina con una lectura más
    List<double> sobre(int segundos) => [for (var i = 0; i < segundos; i++) 18];

    test('sobre el límite durante 5 s es un evento, todavía abierto', () {
      final evento = _de(vel, _eventos([16, ...sobre(7)])).single;
      // Fecha, posición y velocidad de la primera lectura sobre el límite
      expect(evento.fecha, _inicio.add(const Duration(seconds: 1)));
      expect(evento.velocidadPreviaMs, 18);
      expect(evento.latitud, _latitud);
      expect(evento.longitud, _longitud);
      expect(evento.velocidadMaximaMs, 18);
      expect(evento.duracionS, 5);
      expect(evento.intensidad, closeTo(18 - 60 / 3.6, 1e-9));
      expect(evento.enCurso, isTrue);
    });

    test('en un tramo largo se actualiza con la máxima y la duración, y se '
        'cierra al bajar del límite', () {
      final avisos = _de(
        vel,
        _eventos([16, 18, 20, 22, 22, 21, 20, 19, 19, 19, 19, 19, 19, 16, 16]),
      );
      // Un solo evento, avisado de nuevo con cada lectura del tramo
      expect(
        {for (final a in avisos) a.fecha},
        {_inicio.add(const Duration(seconds: 1))},
      );
      expect(
        [for (final a in avisos) a.duracionS],
        [5, 6, 7, 8, 9, 10, 11, 11],
      );
      expect(
        [for (final a in avisos) a.enCurso],
        [...List.filled(7, true), false],
      );
      final cerrado = avisos.last;
      expect(cerrado.velocidadMaximaMs, 22);
      expect(cerrado.duracionS, 11);
      expect(cerrado.intensidad, closeTo(22 - 60 / 3.6, 1e-9));
      expect(cerrado.velocidadPreviaMs, 18);
    });

    test('un hueco de más de 3 s cierra el evento con lo acumulado', () {
      final unicos = _unicos(
        _de(
          vel,
          _eventos(
            [16, ...sobre(6), 18, 18, 16, 16],
            segundos: [0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 13],
          ),
        ),
      );
      expect(unicos, hasLength(1));
      expect(unicos.single.enCurso, isFalse);
      expect(unicos.single.duracionS, 5);
    });

    test('menos de 5 s no es exceso', () {
      expect(_de(vel, _eventos([16, ...sobre(5), 16, 16])), isEmpty);
    });

    test('justo en el límite no es exceso', () {
      expect(
        _de(vel, _eventos([for (var i = 0; i < 10; i++) 60 / 3.6])),
        isEmpty,
      );
    });

    test('un tramo largo es un solo evento', () {
      expect(_unicos(_de(vel, _eventos([16, ...sobre(13)]))), hasLength(1));
    });

    test('dos tramos separados por una bajada son dos eventos', () {
      final unicos = _unicos(
        _de(vel, _eventos([16, ...sobre(6), 16, 16, ...sobre(7)])),
      );
      expect(unicos, hasLength(2));
      // El primero se cerró al bajar; el segundo sigue abierto
      expect([for (final e in unicos) e.enCurso], [false, true]);
    });

    test('una caída de una sola lectura que el filtro quita no corta el '
        'tramo', () {
      expect(
        _unicos(_de(vel, _eventos([16, 18, 18, 18, 15, 18, 18, 18, 18]))),
        hasLength(1),
      );
    });

    test('tras un hueco de más de 3 s el tramo vuelve a empezar', () {
      expect(
        _de(
          vel,
          _eventos(
            [16, 18, 18, 18, 18, 18, 18, 18],
            segundos: [0, 1, 2, 3, 9, 10, 11, 12],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('Exceso de velocidad en el viaje', () {
    const vel = TipoEvento.excesoVelocidad;

    ViajeActivo viaje() => ViajeActivo(
      recorridoId: 1,
      fechaInicioServidor: _inicio,
      acumulador: AcumuladorRecorrido(inicio: _inicio),
    );

    /// Pasa [velocidades] (1 por segundo) con el detector conectado al viaje
    /// como en `ViajeNotifier`; [alRegistrar] se llama tras cada aviso.
    void conducir(
      ViajeActivo viaje,
      List<double> velocidades, {
      void Function()? alRegistrar,
    }) {
      final captura = _Captura();
      captura.detector.alDetectar = (evento) {
        viaje.registrarEvento(evento);
        alRegistrar?.call();
      };
      for (var i = 0; i < velocidades.length; i++) {
        captura.gps(
          _lectura(_inicio.add(Duration(seconds: i)), velocidades[i]),
        );
      }
    }

    test('registrarEvento reemplaza las actualizaciones y agrega los '
        'distintos', () {
      final v = viaje();
      // Subir de 16 a 20 m/s en 1 s (aceleración severa), un exceso de 12 s
      // y, al bajar, una frenada brusca
      conducir(v, [16, ...List.filled(12, 20.0), 16, 16]);
      expect(
        [for (final e in v.eventos) e.tipo],
        [TipoEvento.aceleracionSevera, vel, TipoEvento.frenadaBrusca],
      );
      expect(v.eventos[1].duracionS, 11);
      expect(v.eventos[1].enCurso, isFalse);
    });

    test('al terminar el viaje se cierra el exceso abierto con lo '
        'acumulado', () {
      final v = viaje();
      // 8 s sobre el límite y el viaje termina sin bajar
      conducir(v, [16, 18, 19, 21, 20, 19, 19, 19, 19, 19]);
      final abierto = v.eventos.single;
      expect(abierto.enCurso, isTrue);
      expect(abierto.duracionS, 7);
      expect(abierto.velocidadMaximaMs, 21);

      v.cerrarEventosEnCurso();
      final cerrado = v.eventos.single;
      expect(cerrado.enCurso, isFalse);
      expect(cerrado.duracionS, 7);
      expect(cerrado.velocidadMaximaMs, 21);
      expect(cerrado.fecha, abierto.fecha);
    });

    test('se guarda en el teléfono con lo acumulado si el viaje se '
        'interrumpe', () async {
      final directorio = await Directory.systemTemp.createTemp('drivesense');
      addTearDown(() => directorio.delete(recursive: true));
      final almacen = AlmacenRecorrido(
        _PreferenciasEnMemoria(),
        directorio: () async => directorio,
      );
      final v = viaje();
      final guardados = <Future<void>>[];
      // Exceso en curso: se guarda con cada aviso, como `ViajeNotifier`, y
      // la app se cierra de golpe sin que baje del límite
      // (cambios de 2 m/s por segundo: sin aceleraciones severas)
      conducir(v, [
        16,
        18,
        20,
        22,
        22,
        21,
        20,
        20,
        20,
      ], alRegistrar: () => guardados.add(almacen.guardarViaje(1, v)));
      expect(guardados, hasLength(2));
      await Future.wait(guardados);

      final leido = (await almacen.leerViaje(1))!;
      final exceso = leido.eventos.single;
      expect(exceso.tipo, vel);
      expect(exceso.enCurso, isTrue);
      expect(exceso.velocidadMaximaMs, 22);
      expect(exceso.duracionS, 6);

      // "Continuar" lo cierra con esos valores
      leido.cerrarEventosEnCurso();
      expect(leido.eventos.single.enCurso, isFalse);
      expect(leido.eventos.single.velocidadMaximaMs, 22);
      expect(leido.eventos.single.duracionS, 6);
    });
  });

  group('Viajes reales (A34)', () {
    const fren = TipoEvento.frenadaBrusca;
    const acel = TipoEvento.aceleracionSevera;
    const giro = TipoEvento.giroAgresivo;
    const vel = TipoEvento.excesoVelocidad;

    test('viaje 63: una curva rápida sin marcar; los giros marcados no', () {
      final eventos = _reproducir('giro_brusco_63.csv');
      final giros = _de(giro, eventos);
      expect(giros, hasLength(1));
      expect(giros.single.velocidadPreviaMs * 3.6, closeTo(59.2, 0.1));
      expect(giros.single.intensidad, closeTo(3.51, 0.01));
    });

    test('viaje 64 detenido: ningún evento', () {
      expect(_reproducir('parada_64.csv'), isEmpty);
    });

    test('viaje 63: la frenada marcada y otra sin marcar', () {
      final eventos = _de(fren, _reproducir('gps_63.csv'));
      expect(eventos, hasLength(2));
      expect(eventos[0].velocidadPreviaMs * 3.6, closeTo(33.0, 0.1));
      expect(eventos[0].intensidad, closeTo(3.07, 0.01));
      expect(eventos[1].velocidadPreviaMs * 3.6, closeTo(25.9, 0.1));
      expect(eventos[1].intensidad, closeTo(3.22, 0.01));
      for (final evento in eventos) {
        expect((evento.latitud, evento.longitud), (_latitud, _longitud));
      }
    });

    test('viaje 64 (tranquilo): una frenada', () {
      final evento = _de(fren, _reproducir('gps_64.csv')).single;
      expect(evento.velocidadPreviaMs * 3.6, closeTo(29.9, 0.1));
      expect(evento.intensidad, closeTo(3.22, 0.01));
    });

    test('viaje 63: un tramo sobre 60 km/h; viaje 64: ninguno', () {
      final exceso = _unicos(_de(vel, _reproducir('gps_63.csv'))).single;
      expect(exceso.velocidadPreviaMs * 3.6, greaterThan(60));
      expect(exceso.velocidadMaximaMs! * 3.6, greaterThanOrEqualTo(63));
      expect(exceso.duracionS, inInclusiveRange(5, 8));
      expect(exceso.enCurso, isFalse);
      expect(_de(vel, _reproducir('gps_64.csv')), isEmpty);
    });

    test('viaje 63: un arranque desde parado sin marcar', () {
      final evento = _de(acel, _reproducir('gps_63.csv')).single;
      expect(evento.velocidadPreviaMs * 3.6, closeTo(0, 0.1));
      expect(evento.intensidad, closeTo(2.74, 0.01));
    });

    test('viaje 64 (tranquilo): un arranque desde parado', () {
      final evento = _de(acel, _reproducir('gps_64.csv')).single;
      expect(evento.velocidadPreviaMs * 3.6, closeTo(0, 0.1));
      expect(evento.intensidad, closeTo(3.59, 0.01));
    });
  });

  group('Persistencia', () {
    final evento = EventoRiesgo(
      tipo: TipoEvento.frenadaBrusca,
      fecha: _inicio,
      intensidad: 3.4,
      latitud: _latitud,
      longitud: _longitud,
      velocidadPreviaMs: 9.5,
    );

    void esIgual(EventoRiesgo leido) {
      expect(leido.tipo, evento.tipo);
      expect(leido.fecha, evento.fecha);
      expect(leido.intensidad, evento.intensidad);
      expect(leido.latitud, evento.latitud);
      expect(leido.longitud, evento.longitud);
      expect(leido.velocidadPreviaMs, evento.velocidadPreviaMs);
    }

    test('el evento sobrevive a toJson/fromJson', () {
      esIgual(EventoRiesgo.fromJson(jsonDecode(jsonEncode(evento))));
    });

    test('el tipo aceleración severa también', () {
      final aceleracion = EventoRiesgo(
        tipo: TipoEvento.aceleracionSevera,
        fecha: _inicio,
        intensidad: 2.8,
        latitud: _latitud,
        longitud: _longitud,
        velocidadPreviaMs: 0,
      );
      final leido = EventoRiesgo.fromJson(jsonDecode(jsonEncode(aceleracion)));
      expect(leido.tipo, TipoEvento.aceleracionSevera);
      expect(leido.intensidad, 2.8);
    });

    test('el exceso de velocidad también', () {
      final exceso = EventoRiesgo(
        tipo: TipoEvento.excesoVelocidad,
        fecha: _inicio,
        intensidad: 1.2,
        latitud: _latitud,
        longitud: _longitud,
        velocidadPreviaMs: 17.9,
        velocidadMaximaMs: 18.9,
        duracionS: 7.5,
        enCurso: true,
      );
      final leido = EventoRiesgo.fromJson(jsonDecode(jsonEncode(exceso)));
      expect(leido.tipo, TipoEvento.excesoVelocidad);
      expect(leido.intensidad, 1.2);
      expect(leido.velocidadMaximaMs, 18.9);
      expect(leido.duracionS, 7.5);
      expect(leido.enCurso, isTrue);
    });

    test('los otros tipos no llevan máxima ni duración', () {
      final json = evento.toJson();
      expect(json.containsKey('velocidad_maxima_ms'), isFalse);
      expect(json.containsKey('duracion_s'), isFalse);
      final leido = EventoRiesgo.fromJson(jsonDecode(jsonEncode(json)));
      expect(leido.velocidadMaximaMs, isNull);
      expect(leido.duracionS, isNull);
      expect(leido.enCurso, isFalse);
    });

    test(
      'lee un evento guardado antes (intensidad_ms2, sin campos nuevos)',
      () {
        final json = evento.toJson()
          ..remove('intensidad')
          ..remove('en_curso')
          ..['intensidad_ms2'] = 3.4;
        final leido = EventoRiesgo.fromJson(json);
        expect(leido.intensidad, 3.4);
        expect(leido.enCurso, isFalse);
        expect(leido.duracionS, isNull);
      },
    );

    test('el viaje en curso conserva sus eventos', () {
      final viaje = ViajeActivo(
        recorridoId: 1,
        fechaInicioServidor: _inicio,
        acumulador: AcumuladorRecorrido(inicio: _inicio),
        eventos: [evento],
      );
      final leido = ViajeActivo.fromJson(jsonDecode(jsonEncode(viaje)));
      esIgual(leido.eventos.single);
    });

    test('un viaje guardado sin eventos los lee vacíos', () {
      final json = ViajeActivo(
        recorridoId: 1,
        fechaInicioServidor: _inicio,
        acumulador: AcumuladorRecorrido(inicio: _inicio),
      ).toJson()..remove('eventos');
      final leido = ViajeActivo.fromJson(jsonDecode(jsonEncode(json)));
      expect(leido.eventos, isEmpty);
      // Se pueden agregar al continuar
      leido.eventos.add(evento);
      expect(leido.eventos, hasLength(1));
    });
  });
}
