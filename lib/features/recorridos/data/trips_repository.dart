import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/trip.dart';
import '../models/trip_history.dart';
import 'device_data.dart';

/// Llamadas a `/recorridos` del backend. Lanza `ErrorApi` si la petición falla.
class RecorridosRepositorio {
  RecorridosRepositorio(this._dio);

  final Dio _dio;

  /// `POST /recorridos` (HU-04), con el teléfono y la versión de la app.
  /// 409 si ya hay uno en curso.
  Future<Recorrido> iniciar({
    required double latitud,
    required double longitud,
  }) async {
    final dispositivo = await DatosDispositivo.leer();
    return _recorrido(
      () => _dio.post<Map<String, dynamic>>(
        '/recorridos',
        data: {'lat_inicio': latitud, 'lon_inicio': longitud, ...dispositivo},
      ),
    );
  }

  /// `GET /recorridos/activo`: el recorrido en curso, o `null` (204).
  Future<Recorrido?> obtenerActivo() async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/recorridos/activo',
      );
      if (respuesta.statusCode == 204 || respuesta.data == null) return null;
      return Recorrido.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  /// `PATCH /recorridos/{id}/finalizar` (HU-05). Devuelve el estado final
  /// (`finalizado` o `descartado`); 409 si ya estaba finalizado.
  Future<Recorrido> finalizar(ResumenRecorrido resumen) => _recorrido(
    () => _dio.patch<Map<String, dynamic>>(
      '/recorridos/${resumen.recorridoId}/finalizar',
      data: resumen.toApiJson(),
    ),
  );

  /// `GET /recorridos` (HU-06): viajes finalizados desde [desde] (nulo = todos),
  /// anteriores al recorrido [antesDe] (nulo = primera página, con el resumen).
  Future<PaginaHistorial> listar({
    DateTime? desde,
    int? antesDe,
    int limite = 20,
  }) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/recorridos',
        queryParameters: {
          // En UTC: un instante con zona, que el backend exige
          'desde': ?desde?.toUtc().toIso8601String(),
          'antes_de': ?antesDe,
          'limite': limite,
        },
      );
      return PaginaHistorial.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  /// `GET /recorridos/{id}` (HU-06). 404 si no es un viaje finalizado propio.
  Future<RecorridoHistorial> obtener(int id) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>('/recorridos/$id');
      return RecorridoHistorial.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  Future<Recorrido> _recorrido(
    Future<Response<Map<String, dynamic>>> Function() peticion,
  ) async {
    try {
      final respuesta = await peticion();
      return Recorrido.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

final recorridosRepositorioProvider = Provider<RecorridosRepositorio>(
  (ref) => RecorridosRepositorio(ref.watch(clienteApiProvider)),
);
