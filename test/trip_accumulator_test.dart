import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/presentation/trip_format.dart';
import 'package:drivesense/features/telemetria/models/event_detector.dart';
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

  group('Detención (viaje olvidado)', () {
    test('sin lecturas cuenta desde el inicio', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      expect(acumulador.detenidoDesde, _inicio);
    });

    test('moverse a la velocidad mínima reinicia la detención', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      for (var s = 0; s <= 10; s++) {
        acumulador.agregar(_lectura(s * 10.0, s)); // 36 km/h
      }
      expect(
        acumulador.detenidoDesde,
        _inicio.add(const Duration(seconds: 10)),
      );
    });

    test('quieto o con temblor del GPS no la reinicia', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0));
      for (var s = 1; s <= 300; s++) {
        acumulador.agregar(
          _lectura(s.isEven ? 3 : 0, s, velocidadKmh: s.isEven ? 2 : 0),
        );
      }
      expect(acumulador.detenidoDesde, _inicio);
    });

    test('avanzar lento más allá del radio la reinicia (atasco)', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      acumulador.agregar(_lectura(0, 0, velocidadKmh: 0));
      // 4 km/h ≈ 1,1 m/s: a los 40 s ya pasó los 40 m
      for (var s = 1; s <= 45; s++) {
        acumulador.agregar(_lectura(s * 1.1, s, velocidadKmh: 4));
      }
      expect(acumulador.detenidoDesde.isAfter(_inicio), isTrue);
      expect(
        acumulador.detenidoDesde.isAfter(
          _inicio.add(const Duration(seconds: 30)),
        ),
        isTrue,
      );
    });

    test('al continuar un viaje interrumpido cuenta desde ese momento', () {
      final acumulador = AcumuladorRecorrido(inicio: _inicio)
        ..agregar(_lectura(0, 0));
      final restaurado = AcumuladorRecorrido.fromJson(acumulador.toJson());
      expect(restaurado.detenidoDesde, _inicio);
      final ahora = _inicio.add(const Duration(hours: 2));
      restaurado.reiniciarDetencion(ahora);
      expect(restaurado.detenidoDesde, ahora);
      // Lecturas quieto después de continuar: sigue contando desde ahí
      restaurado.agregar(_lectura(0, 7201, velocidadKmh: 0));
      restaurado.agregar(_lectura(0, 7300, velocidadKmh: 0));
      expect(
        restaurado.detenidoDesde,
        _inicio.add(const Duration(seconds: 7201)),
      );
    });
  });

  group('ResumenRecorrido', () {
    test(
      'al finalizar solo descarta la ruta y los eventos posteriores al fin',
      () {
        final acumulador = AcumuladorRecorrido(inicio: _inicio);
        final viaje = ViajeActivo(
          recorridoId: 1,
          fechaInicioServidor: _inicio,
          acumulador: acumulador,
        );
        for (var s = 0; s <= 600; s += 10) {
          final lectura = _lectura(s < 300 ? s * 10.0 : 3000, s);
          acumulador.agregar(lectura);
          viaje.ruta.agregar(lectura);
        }
        EventoRiesgo evento(int segundos) => EventoRiesgo(
          tipo: TipoEvento.values.first,
          fecha: _inicio.add(Duration(seconds: segundos)),
          intensidad: 4,
          latitud: -17.78,
          longitud: -63.18,
          velocidadPreviaMs: 10,
        );
        viaje.registrarEvento(evento(100));
        viaje.registrarEvento(evento(500));
        final fin = _inicio.add(const Duration(seconds: 300));

        final recortado = ResumenRecorrido.desde(
          viaje,
          fechaFin: fin,
          llegada: acumulador.ultimaLectura!,
          recortar: true,
        );
        expect(recortado.ruta!.every((p) => !p.fecha.isAfter(fin)), isTrue);
        expect(recortado.ruta!.last.fecha, fin);
        expect(recortado.eventos, hasLength(1));
        expect(recortado.duracionS, 300);

        // Al finalizar a mano no se recorta nada
        final completo = ResumenRecorrido.desde(
          viaje,
          fechaFin: fin,
          llegada: acumulador.ultimaLectura!,
        );
        expect(completo.ruta!.length, greaterThan(recortado.ruta!.length));
        expect(completo.eventos, hasLength(2));
      },
    );

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
