import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/presentation/trip_format.dart';
import 'package:flutter_test/flutter_test.dart';

// ~0,000009° de latitud ≈ 1 m
const _gradosPorMetro = 1 / 111195;
final _inicio = DateTime.utc(2026, 9, 27, 12);

/// Lectura a [metrosNorte] del origen, [segundos] después del inicio.
Lectura _lectura(
  double metrosNorte,
  int segundos, {
  double precision = 5,
  double velocidadKmh = 36,
}) => Lectura(
  latitud: -17.78 + metrosNorte * _gradosPorMetro,
  longitud: -63.18,
  precisionM: precision,
  velocidadMs: velocidadKmh / 3.6,
  fecha: _inicio.add(Duration(seconds: segundos)),
);

void main() {
  group('AcumuladorRecorrido', () {
    test('suma los tramos entre lecturas', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      for (var s = 0; s <= 10; s++) {
        acumulador.agregar(_lectura(s * 10.0, s)); // 10 m/s
      }
      expect(acumulador.distanciaM, closeTo(100, 0.5));
      expect(acumulador.velocidadMaximaKmh, 36);
    });

    test('descarta lecturas imprecisas', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0));
      expect(acumulador.agregar(_lectura(500, 1, precision: 50)), isFalse);
      acumulador.agregar(_lectura(10, 2));
      expect(acumulador.distanciaM, closeTo(10, 0.5));
    });

    test('descarta saltos imposibles', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0));
      // 1 km en 1 s = 3600 km/h
      expect(acumulador.agregar(_lectura(1000, 1)), isFalse);
      acumulador.agregar(_lectura(20, 2));
      expect(acumulador.distanciaM, closeTo(20, 0.5));
    });

    test('tras varios saltos seguidos se reubica sin sumar el tramo', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0)); // lectura errónea
      acumulador.agregar(_lectura(1000, 1));
      acumulador.agregar(_lectura(1010, 2));
      expect(acumulador.agregar(_lectura(1020, 3)), isTrue);
      expect(acumulador.distanciaM, 0);
      acumulador.agregar(_lectura(1030, 4));
      expect(acumulador.distanciaM, closeTo(10, 0.5));
    });

    test('no suma el temblor del GPS con el teléfono quieto', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0, velocidadKmh: 0));
      for (var s = 1; s <= 30; s++) {
        final metros = s.isEven ? 3.0 : -3.0;
        acumulador.agregar(_lectura(metros, s, precision: 8, velocidadKmh: 0));
      }
      expect(acumulador.distanciaM, 0);
    });

    test('la velocidad actual vuelve a 0 sin lecturas recientes', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0, velocidadKmh: 50));
      final lectura = _inicio;
      expect(acumulador.velocidadActualKmh(lectura), closeTo(50, 0.01));
      expect(
        acumulador.velocidadActualKmh(lectura.add(const Duration(seconds: 6))),
        0,
      );
    });

    test('el promedio nunca supera la máxima', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0, velocidadKmh: 10));
      acumulador.agregar(_lectura(100, 10, velocidadKmh: 10)); // 36 km/h reales
      expect(acumulador.velocidadPromedioKmh(10), 10);
      expect(acumulador.velocidadPromedioKmh(0), 0);
    });

    test('al restaurarlo no une el hueco sin registrar', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0));
      acumulador.agregar(_lectura(10, 1));

      final restaurado = AcumuladorRecorrido.fromJson(acumulador.toJson());
      expect(restaurado.distanciaM, closeTo(10, 0.5));
      expect(
        restaurado.ultimaLectura!.fecha,
        _inicio.add(const Duration(seconds: 1)),
      );

      // Reaparece 2 km más allá 10 min después: ese tramo no se suma
      restaurado.agregar(_lectura(2000, 600));
      restaurado.agregar(_lectura(2010, 601));
      expect(restaurado.distanciaM, closeTo(20, 0.5));
    });
  });

  group('ResumenRecorrido', () {
    test('la fecha de fin nunca queda antes del inicio del servidor', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0));
      final viaje = ViajeActivo(
        recorridoId: 1,
        // El reloj del teléfono va 30 s atrasado respecto al servidor
        fechaInicioServidor: _inicio.add(const Duration(seconds: 30)),
        acumulador: acumulador,
      );
      final resumen = ResumenRecorrido.desde(
        viaje,
        fechaFin: _inicio.add(const Duration(seconds: 10)),
        llegada: acumulador.ultimaLectura!,
      );
      expect(resumen.fechaFin.isAfter(viaje.fechaInicioServidor), isTrue);
      expect(resumen.toApiJson()['fecha_fin'], endsWith('Z'));
    });
  });

  test('FormatoViaje', () {
    expect(FormatoViaje.duracion(75), '01:15');
    expect(FormatoViaje.duracion(3725), '01:02:05');
    expect(FormatoViaje.kilometros(1254), '1,25');
    expect(FormatoViaje.velocidad(47.6), '48');

    final fin = DateTime(2026, 9, 27, 16, 23);
    expect(
      FormatoViaje.franjaHoraria(fin, 18 * 60, ahora: fin),
      'Hoy · 16:05 – 16:23',
    );
    expect(
      FormatoViaje.franjaHoraria(fin, 60, ahora: DateTime(2026, 9, 28, 9)),
      '27/09 · 16:22 – 16:23',
    );
  });
}
