import 'dart:io';
import 'dart:math' as math;

import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/telemetria/models/sensor_sample.dart';
import 'package:drivesense/features/telemetria/models/signal_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _g = 9.81;
final _inicio = DateTime.utc(2026, 10, 1, 12);

/// Vector (x, y, z) en el sistema del teléfono.
typedef _V = (double, double, double);

_V _unitario(_V v) {
  final n = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3);
  return (v.$1 / n, v.$2 / n, v.$3 / n);
}

/// Alimenta el filtro como lo haría el teléfono: 50 Hz de acelerómetro y
/// giroscopio, con el reloj avanzando.
class _Simulador {
  _Simulador({this.conGiroscopio = true});

  final bool conGiroscopio;
  final filtro = FiltroSenal();
  final _azar = math.Random(1);
  Duration t = Duration.zero;

  DateTime get ahora => _inicio.add(t);

  /// [segundos] con la vertical del teléfono en [vertical] (unitario), el
  /// auto girando a [giro] rad/s, más [extra] en el acelerómetro y [rotacion]
  /// en el giroscopio; [ruido] y [ruidoGiro], vibración uniforme en cada eje.
  /// [vertical] puede cambiar con el tiempo (s desde el
  /// inicio del tramo).
  void avanzar(
    double segundos, {
    _V Function(double s)? vertical,
    double giro = 0,
    _V extra = (0, 0, 0),
    _V rotacion = (0, 0, 0),
    double ruido = 0,
    double? ruidoGiro,
  }) {
    final pasos = (segundos * 50).round();
    for (var i = 0; i < pasos; i++) {
      t += const Duration(milliseconds: 20);
      final u = (vertical ?? (_) => (0.0, 0.0, 1.0))(i / 50);
      double r() => ruido * (_azar.nextDouble() * 2 - 1);
      double rg() => (ruidoGiro ?? ruido) * (_azar.nextDouble() * 2 - 1);
      filtro.acelerometro(
        MuestraSensor(
          fecha: ahora,
          x: _g * u.$1 + extra.$1 + r(),
          y: _g * u.$2 + extra.$2 + r(),
          z: _g * u.$3 + extra.$3 + r(),
        ),
      );
      if (conGiroscopio) {
        filtro.giroscopio(
          MuestraSensor(
            fecha: ahora,
            x: giro * u.$1 + rotacion.$1 + rg(),
            y: giro * u.$2 + rotacion.$2 + rg(),
            z: giro * u.$3 + rotacion.$3 + rg(),
          ),
        );
      }
    }
  }
}

Lectura _lectura(int segundo, double velocidadMs, {double precisionM = 5}) =>
    Lectura(
      latitud: -17.78,
      longitud: -63.18,
      precisionM: precisionM,
      velocidadMs: velocidadMs,
      fecha: _inicio.add(Duration(seconds: segundo)),
    );

/// Velocidades confirmadas tras pasar [velocidades] (1 por segundo).
List<double> _confirmadas(List<double> velocidades, {int? malaPrecision}) {
  final filtro = FiltroSenal();
  for (var i = 0; i < velocidades.length; i++) {
    filtro.gps(
      _lectura(i, velocidades[i], precisionM: i == malaPrecision ? 25 : 5),
    );
  }
  return [for (final v in filtro.velocidades) v.velocidadMs];
}

/// Reproduce un CSV de calibración (como lo graba la app) en el filtro.
/// [alGiro] recibe el giro tras cada muestra del giroscopio.
FiltroSenal _reproducir(
  String archivo, {
  void Function(DateTime fecha, FiltroSenal filtro)? alGiro,
  void Function(Lectura lectura, FiltroSenal filtro)? alGps,
}) {
  final filtro = FiltroSenal();
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
        filtro.acelerometro(muestra());
      case 'gir':
        filtro.giroscopio(muestra());
        alGiro?.call(fecha, filtro);
      case 'gps':
        final lectura = Lectura(
          latitud: 0,
          longitud: 0,
          precisionM: double.parse(c[7]),
          velocidadMs: double.parse(c[8]),
          fecha: fecha,
        );
        filtro.gps(lectura);
        alGps?.call(lectura, filtro);
    }
  }
  return filtro;
}

void main() {
  group('Giro', () {
    test('se mide alrededor de la vertical, esté como esté el teléfono', () {
      for (final vertical in <_V>[
        (0, 0, 1),
        (0, 1, 0),
        _unitario((1, 1, 1)),
        _unitario((-0.3, 0.8, 0.5)),
      ]) {
        final sim = _Simulador()
          ..avanzar(10, vertical: (_) => vertical, giro: 0.5);
        expect(sim.filtro.giroRadS, closeTo(0.5, 0.01), reason: '$vertical');
        expect(sim.filtro.descarte, isNull);
      }
    });

    test('detenido y quieto, con ruido, queda en cero', () {
      final sim = _Simulador()..avanzar(10, ruido: 0.05);
      for (var i = 0; i < 5; i++) {
        sim.filtro.gps(_lectura(i, 0));
      }
      expect(sim.filtro.giroRadS, 0);
      expect(sim.filtro.velocidades.last.velocidadMs, 0);
      expect(sim.filtro.descarte, isNull);
    });

    test('no hay giro hasta tener la vertical', () {
      final sim = _Simulador()..avanzar(1, giro: 0.5);
      expect(sim.filtro.giroRadS, isNull);
      expect(sim.filtro.descarte, MotivoDescarte.sinGravedad);
    });

    test('sin giroscopio sigue la velocidad, sin giro', () {
      final sim = _Simulador(conGiroscopio: false)..avanzar(10);
      sim.filtro
        ..sinGiroscopio()
        ..gps(_lectura(0, 8))
        ..gps(_lectura(1, 9));
      expect(sim.filtro.giroRadS, isNull);
      expect(sim.filtro.velocidades, isNotEmpty);
    });
  });

  group('Vertical', () {
    test('una frenada sostenida no inclina la vertical ni se descarta', () {
      final sim = _Simulador()..avanzar(30);
      final desde = sim.ahora;
      sim.avanzar(3, extra: (-3, 0, 0), giro: 0.2);
      expect(sim.filtro.descarte, isNull);
      expect(sim.filtro.confiable(desde, sim.ahora), isTrue);
      expect(sim.filtro.giroRadS, closeTo(0.2, 0.01));
    });

    test('si el teléfono cambia de posición, descarta el tramo y vuelve a '
        'calcular la vertical', () {
      final sim = _Simulador()..avanzar(10);
      final giraDesde = sim.ahora;
      // Gira 90° sobre su eje x en 1 s: la vertical pasa de z a y
      sim.avanzar(
        1,
        vertical: (s) =>
            (0, math.sin(s * math.pi / 2), math.cos(s * math.pi / 2)),
        rotacion: (math.pi / 2, 0, 0),
      );
      expect(sim.filtro.descarte, MotivoDescarte.telefonoMovido);
      final giraHasta = sim.ahora;

      // Queda quieto en la nueva posición y el auto gira
      sim.avanzar(6, vertical: (_) => (0, 1, 0), giro: 0.4);
      expect(sim.filtro.descarte, isNull);
      expect(sim.filtro.confiable(giraDesde, giraHasta), isFalse);
      expect(sim.filtro.giroRadS, closeTo(0.4, 0.02));
    });
  });

  group('Bache', () {
    test('un golpe vertical fuerte descarta ±1 s', () {
      final sim = _Simulador()..avanzar(10);
      final golpe = sim.ahora;
      sim.avanzar(0.1, extra: (0, 0, 8));
      expect(sim.filtro.descarte, MotivoDescarte.bache);
      expect(
        sim.filtro.confiable(
          golpe.subtract(const Duration(milliseconds: 500)),
          golpe,
        ),
        isFalse,
      );

      sim.avanzar(3);
      expect(sim.filtro.descarte, isNull);
      expect(
        sim.filtro.confiable(
          sim.ahora.subtract(const Duration(seconds: 1)),
          sim.ahora,
        ),
        isTrue,
      );
    });

    test('la vibración del motor no se descarta', () {
      final sim = _Simulador()..avanzar(15, ruido: 3, ruidoGiro: 0.3);
      expect(sim.filtro.descarte, isNull);
      expect(sim.filtro.confiable(_inicio, sim.ahora), isTrue);
    });
  });

  group('Velocidad del GPS', () {
    test('descarta las lecturas imprecisas o sin velocidad', () {
      expect(_confirmadas([10, 11, 12, 13], malaPrecision: 1), [10, 12]);
      expect(_confirmadas([10, -1, 12, 13]), [10, 12]);
    });

    test('descarta una caída de una sola lectura que se recupera', () {
      // El último valor espera al siguiente para confirmarse
      expect(_confirmadas([10, 10, 0, 10, 10]), [10, 10, 10]);
    });

    test('descarta un pico de una sola lectura', () {
      expect(_confirmadas([5, 5, 12, 5, 5]), [5, 5, 5]);
    });

    test('conserva una frenada real', () {
      expect(_confirmadas([10, 7, 4, 1, 0, 0]), [10, 7, 4, 1, 0]);
    });

    test('tras un hueco no compara con lecturas lejanas', () {
      final filtro = FiltroSenal()
        ..gps(_lectura(0, 10))
        ..gps(_lectura(10, 0))
        ..gps(_lectura(11, 10))
        ..gps(_lectura(12, 10));
      expect([for (final v in filtro.velocidades) v.velocidadMs], [10, 0, 10]);
    });
  });

  group('Viajes reales (A34)', () {
    test('el giro brusco marcado se mide y no se descarta', () {
      var maximo = 0.0;
      DateTime? enMaximo;
      final filtro = _reproducir(
        'giro_brusco_63.csv',
        alGiro: (fecha, filtro) {
          final giro = filtro.giroRadS?.abs() ?? 0;
          if (giro > maximo) {
            maximo = giro;
            enMaximo = fecha;
          }
        },
      );
      expect(maximo, greaterThan(0.4));
      expect(
        filtro.confiable(
          enMaximo!.subtract(const Duration(seconds: 1)),
          enMaximo!.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('detenido, el giro queda prácticamente en cero', () {
      final giros = <double>[];
      _reproducir(
        'parada_64.csv',
        alGiro: (fecha, filtro) {
          final giro = filtro.giroRadS;
          if (giro != null && filtro.descarte == null) giros.add(giro.abs());
        },
      );
      expect(giros, isNotEmpty);
      giros.sort();
      // Mediana y percentil 95
      expect(giros[giros.length ~/ 2], lessThan(0.03));
      expect(giros[(giros.length * 0.95).floor()], lessThan(0.1));
    });

    test('quita los instantes en 0 km/h entre dos lecturas normales', () {
      final confirmadas = <DateTime, double>{};
      final crudas = <Lectura>[];
      _reproducir(
        'gps_64.csv',
        alGps: (lectura, filtro) {
          crudas.add(lectura);
          for (final v in filtro.velocidades) {
            confirmadas[v.fecha] = v.velocidadMs;
          }
        },
      );
      // Los cinco ceros aislados del viaje
      final aislados = [
        for (var i = 1; i < crudas.length - 1; i++)
          if (crudas[i].velocidadMs == 0 &&
              crudas[i - 1].velocidadMs > 1.5 &&
              crudas[i + 1].velocidadMs > 1.5)
            crudas[i].fecha,
      ];
      expect(aislados, hasLength(5));
      for (final fecha in aislados) {
        expect(confirmadas.containsKey(fecha), isFalse);
      }
      // Todas las demás se conservan (menos la última, que espera)
      expect(confirmadas.length, crudas.length - aislados.length - 1);
    });
  });
}
