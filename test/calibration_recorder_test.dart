import 'dart:io';

import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/telemetria/data/calibration_recorder.dart';
import 'package:drivesense/features/telemetria/models/calibration_mark.dart';
import 'package:drivesense/features/telemetria/models/sensor_sample.dart';
import 'package:flutter_test/flutter_test.dart';

final _instante = DateTime.utc(2026, 10, 1, 12);

void main() {
  late Directory directorio;
  late RegistroCalibracion registro;

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('calibracion_');
    registro = RegistroCalibracion(directorio: () async => directorio);
  });

  tearDown(() => directorio.delete(recursive: true));

  Future<List<String>> grabar(void Function() acciones) async {
    registro.iniciar(1, nuevo: true);
    acciones();
    final archivo = await registro.detener();
    return (await archivo!.readAsString()).trim().split('\n');
  }

  test(
    'todas las filas tienen la columna etiqueta, vacía salvo en las marcas',
    () async {
      final lineas = await grabar(() {
        registro.sensor(
          TipoSensor.acelerometro,
          MuestraSensor(fecha: _instante, x: 1, y: 2, z: 3),
        );
        registro.gps(
          Lectura(
            latitud: -17.78,
            longitud: -63.18,
            precisionM: 5,
            velocidadMs: 10,
            fecha: _instante,
          ),
        );
        registro.marca(TipoMarca.frenadaFuerte, _instante);
        registro.marca(TipoMarca.aceleracionFuerte, _instante);
      });

      expect(
        lineas.first,
        'tipo,fecha_us,x,y,z,lat,lon,precision_m,velocidad_ms,etiqueta',
      );
      for (final linea in lineas) {
        expect(linea.split(',').length, 10, reason: linea);
      }
      expect(lineas[1], startsWith('acc,'));
      expect(lineas[1], endsWith(','));
      expect(lineas[2], startsWith('gps,'));
      expect(lineas[2], endsWith(','));
      expect(
        lineas[3],
        'marca,${_instante.microsecondsSinceEpoch},,,,,,,,frenada_fuerte',
      );
      expect(
        lineas[4],
        'marca,${_instante.microsecondsSinceEpoch},,,,,,,,aceleracion_fuerte',
      );
    },
  );

  test(
    'cuenta las marcas de cada tipo y reinicia al empezar otra grabación',
    () async {
      await grabar(() {
        registro.marca(TipoMarca.bache, _instante);
        registro.marca(TipoMarca.bache, _instante);
        registro.marca(TipoMarca.telefonoMovido, _instante);
        registro.marca(TipoMarca.aceleracionFuerte, _instante);
      });
      expect(registro.marcas(TipoMarca.bache), 2);
      expect(registro.marcas(TipoMarca.telefonoMovido), 1);
      expect(registro.marcas(TipoMarca.aceleracionFuerte), 1);
      expect(registro.marcas(TipoMarca.giroBrusco), 0);

      registro.iniciar(2, nuevo: true);
      expect(registro.marcas(TipoMarca.bache), 0);
      await registro.detener();
    },
  );

  test('sin grabar no registra marcas', () {
    registro.marca(TipoMarca.giroBrusco, _instante);
    expect(registro.marcas(TipoMarca.giroBrusco), 0);
  });
}
