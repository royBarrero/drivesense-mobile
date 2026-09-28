import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/recorridos/data/trips_repository.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

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

RecorridosRepositorio _repositorio(_AdaptadorFijo adaptador) =>
    RecorridosRepositorio(Dio()..httpClientAdapter = adaptador);

const _recorrido = {
  'id': 7,
  'estado': 'descartado',
  'fecha_inicio': '2026-09-27T19:36:12.969881Z',
};

void main() {
  test('obtenerActivo devuelve null con 204', () async {
    final activo = await _repositorio(_AdaptadorFijo(204)).obtenerActivo();
    expect(activo, isNull);
  });

  test('finalizar envía el resumen y lee el estado final', () async {
    final adaptador = _AdaptadorFijo(200, _recorrido);
    final resumen = ResumenRecorrido(
      recorridoId: 7,
      fechaFin: DateTime.utc(2026, 9, 27, 20),
      distanciaM: 150,
      duracionS: 30,
      velocidadMaximaKmh: 20,
      velocidadPromedioKmh: 18,
      latitudFin: -17.79,
      longitudFin: -63.19,
    );

    final recorrido = await _repositorio(adaptador).finalizar(resumen);

    expect(recorrido.estado, EstadoRecorrido.descartado);
    expect(adaptador.ultimaPeticion!.path, '/recorridos/7/finalizar');
    expect(adaptador.ultimaPeticion!.method, 'PATCH');
    expect(
      (adaptador.ultimaPeticion!.data as Map)['fecha_fin'],
      '2026-09-27T20:00:00.000Z',
    );
  });

  test('un 409 llega como ErrorApi con el detail del backend', () async {
    final adaptador = _AdaptadorFijo(409, {
      'detail': 'Ya tienes un recorrido en curso',
    });
    expect(
      () => _repositorio(adaptador).iniciar(latitud: 1, longitud: 2),
      throwsA(
        isA<ErrorApi>()
            .having((e) => e.codigo, 'codigo', 409)
            .having(
              (e) => e.mensaje,
              'mensaje',
              'Ya tienes un recorrido en curso',
            ),
      ),
    );
  });
}
