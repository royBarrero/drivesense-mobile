import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/telemetria/models/rate_limiter.dart';
import 'package:drivesense/features/telemetria/models/route.dart';
import 'package:drivesense/features/telemetria/models/sensor_buffer.dart';
import 'package:drivesense/features/telemetria/models/sensor_sample.dart';
import 'package:flutter_test/flutter_test.dart';

final _inicio = DateTime.utc(2026, 9, 29, 12);

MuestraSensor _muestra(int ms, [double x = 0]) => MuestraSensor(
  fecha: _inicio.add(Duration(milliseconds: ms)),
  x: x,
  y: 0,
  z: 9.8,
);

/// Lectura a [metrosNorte] del punto de partida, [segundos] después del inicio.
Lectura _lectura(double metrosNorte, num segundos, {double velocidadMs = 10}) =>
    Lectura(
      // ~111 320 m por grado de latitud
      latitud: -17.78 + metrosNorte / 111320,
      longitud: -63.18,
      precisionM: 5,
      velocidadMs: velocidadMs,
      fecha: _inicio.add(Duration(milliseconds: (segundos * 1000).round())),
    );

void main() {
  group('BuferCircular', () {
    test('conserva las últimas en orden cronológico al llenarse', () {
      final bufer = BuferCircular(capacidad: 3);
      expect(bufer.vacio, isTrue);
      expect(bufer.ultima, isNull);

      for (var i = 0; i < 5; i++) {
        bufer.agregar(_muestra(i * 20, i.toDouble()));
      }

      expect(bufer.cantidad, 3);
      expect(bufer.muestras.map((m) => m.x), [2, 3, 4]);
      expect(bufer.ultima!.x, 4);
    });

    test('por defecto guarda ~10 s a 50 Hz', () {
      final bufer = BuferCircular();
      for (var i = 0; i < 600; i++) {
        bufer.agregar(_muestra(i * 20));
      }
      expect(bufer.cantidad, 500);
      final muestras = bufer.muestras;
      expect(
        muestras.last.fecha.difference(muestras.first.fecha),
        const Duration(milliseconds: 499 * 20),
      );
    });

    test('ventana devuelve las muestras del intervalo', () {
      final bufer = BuferCircular();
      for (var i = 0; i < 200; i++) {
        bufer.agregar(_muestra(i * 20)); // 4 s a 50 Hz
      }
      // Último segundo hasta la más reciente
      expect(bufer.ventana(const Duration(seconds: 1)).length, 50);
      // Hasta un instante posterior: las que siguen dentro de la ventana
      final hasta = bufer.ultima!.fecha.add(const Duration(milliseconds: 500));
      expect(
        bufer.ventana(const Duration(seconds: 1), hasta: hasta).length,
        25,
      );
      // Sensor detenido hace rato: nada
      expect(
        bufer
            .ventana(
              const Duration(seconds: 1),
              hasta: hasta.add(const Duration(seconds: 5)),
            )
            .length,
        0,
      );
    });

    test('vaciar', () {
      final bufer = BuferCircular(capacidad: 2)
        ..agregar(_muestra(0))
        ..vaciar();
      expect(bufer.vacio, isTrue);
      expect(bufer.muestras, isEmpty);
    });
  });

  group('LimitadorFrecuencia', () {
    int aceptadas(LimitadorFrecuencia limite, Iterable<int> ms) => ms
        .where((m) => limite.aceptar(_inicio.add(Duration(milliseconds: m))))
        .length;

    test('un sensor a 125 Hz queda en 50 Hz', () {
      final limite = LimitadorFrecuencia(const Duration(milliseconds: 20));
      // 10 s cada 8 ms
      expect(aceptadas(limite, [for (var i = 0; i < 1250; i++) i * 8]), 500);
    });

    test('a 50 Hz con variación no descarta muestras', () {
      final limite = LimitadorFrecuencia(const Duration(milliseconds: 20));
      final ms = [for (var i = 0; i < 500; i++) i * 20 + (i.isEven ? 1 : -1)];
      expect(aceptadas(limite, ms), 500);
    });

    test('tras un hueco la grilla vuelve a empezar', () {
      final limite = LimitadorFrecuencia(const Duration(milliseconds: 20));
      expect(aceptadas(limite, [0, 20, 1000, 1008, 1020, 1040]), 5);
    });
  });

  group('ConstructorRuta', () {
    test('un punto cada 5 s con el auto quieto', () {
      final ruta = ConstructorRuta();
      for (var s = 0; s <= 12; s++) {
        ruta.agregar(_lectura(0, s, velocidadMs: 0));
      }
      expect(ruta.puntos.map((p) => p.fecha.second), [0, 5, 10]);
    });

    test('un punto cada 20 m si se avanza antes de 5 s', () {
      final ruta = ConstructorRuta();
      // 12 m/s: 20 m se cumplen cada 2 s
      for (var s = 0; s <= 6; s++) {
        ruta.agregar(_lectura(s * 12.0, s));
      }
      expect(ruta.puntos.map((p) => p.fecha.second), [0, 2, 4, 6]);
    });

    test('ignora lecturas anteriores al último punto', () {
      final ruta = ConstructorRuta()..agregar(_lectura(0, 10));
      expect(ruta.agregar(_lectura(100, 4)), isFalse);
      expect(ruta.cantidad, 1);
    });

    test('guarda la velocidad en km/h, sin pasar el límite del backend', () {
      final ruta = ConstructorRuta()
        ..agregar(_lectura(0, 0, velocidadMs: 10))
        ..agregar(_lectura(0, 5, velocidadMs: 100));
      expect(ruta.puntos.first.velocidadKmh, closeTo(36, 0.001));
      expect(ruta.puntos.last.velocidadKmh, 300);
    });

    test('al pasar el límite se diezma conservando primero y último', () {
      final ruta = ConstructorRuta();
      for (var i = 0; i <= UmbralesRuta.maximoPuntos; i++) {
        ruta.agregar(_lectura(0, i * 5, velocidadMs: 0));
      }
      final puntos = ruta.puntos;
      expect(puntos.length, lessThanOrEqualTo(UmbralesRuta.maximoPuntos));
      expect(puntos.length, UmbralesRuta.maximoPuntos ~/ 2 + 1);
      expect(puntos.first.fecha, _inicio);
      expect(
        puntos.last.fecha,
        _inicio.add(Duration(seconds: UmbralesRuta.maximoPuntos * 5)),
      );
      // Tras diezmar hay que reescribir el archivo completo
      expect(ruta.tomarSinGuardar().completa, isTrue);
    });

    test('tomarSinGuardar entrega solo los puntos nuevos', () {
      final ruta = ConstructorRuta([PuntoRuta.desde(_lectura(0, 0))])
        ..agregar(_lectura(0, 5))
        ..agregar(_lectura(0, 10));
      final primera = ruta.tomarSinGuardar();
      expect(primera.completa, isFalse);
      expect(primera.puntos.length, 2);
      expect(ruta.tomarSinGuardar().puntos, isEmpty);
    });

    test('PuntoRuta ida y vuelta por JSON (fecha en UTC)', () {
      final punto = PuntoRuta.desde(_lectura(10, 3));
      final json = punto.toJson();
      expect(json.keys, ['lat', 'lon', 'fecha', 'velocidad_kmh']);
      expect(json['fecha'], endsWith('Z'));
      final copia = PuntoRuta.fromJson(json);
      expect(copia.latitud, punto.latitud);
      expect(copia.fecha, punto.fecha);
    });
  });

  group('ResumenRecorrido con ruta', () {
    ViajeActivo viaje() {
      final acumulador = AcumuladorRecorrido(inicio: _inicio);
      final viaje = ViajeActivo(
        recorridoId: 4,
        fechaInicioServidor: _inicio,
        acumulador: acumulador,
      );
      for (final lectura in [_lectura(0, 0), _lectura(50, 5)]) {
        acumulador.agregar(lectura);
        viaje.ruta.agregar(lectura);
      }
      return viaje;
    }

    test('envía la ruta del viaje y la conserva como pendiente', () {
      final v = viaje();
      final resumen = ResumenRecorrido.desde(
        v,
        fechaFin: _inicio.add(const Duration(minutes: 2)),
        llegada: v.acumulador.ultimaLectura!,
      );
      final api = resumen.toApiJson();
      expect(api['ruta'], hasLength(2));
      expect((api['ruta'] as List).first, containsPair('lat', -17.78));

      final guardado = ResumenRecorrido.fromJson(resumen.toJson());
      expect(guardado.ruta, hasLength(2));
    });

    test('un pendiente de una versión anterior se envía sin ruta', () {
      final json = ResumenRecorrido.desde(
        viaje(),
        fechaFin: _inicio.add(const Duration(minutes: 2)),
        llegada: _lectura(50, 5),
      ).toJson()..remove('ruta');

      final antiguo = ResumenRecorrido.fromJson(json);
      expect(antiguo.ruta, isNull);
      expect(antiguo.toApiJson().containsKey('ruta'), isFalse);
    });

    test('ViajeActivo guarda la marca sin giroscopio pero no la ruta', () {
      final v = viaje()..sinGiroscopio = true;
      final json = v.toJson();
      expect(json.containsKey('ruta'), isFalse);

      final restaurado = ViajeActivo.fromJson(json, ruta: v.ruta.puntos);
      expect(restaurado.sinGiroscopio, isTrue);
      expect(restaurado.ruta.cantidad, 2);
      // Lo restaurado ya estaba en el archivo
      expect(restaurado.ruta.tomarSinGuardar().puntos, isEmpty);
    });
  });
}
