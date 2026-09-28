import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/trip.dart';

/// Llamadas a `/recorridos` del backend. Lanza `ErrorApi` si la petición falla.
class RecorridosRepositorio {
  RecorridosRepositorio(this._dio);

  final Dio _dio;

  /// `POST /recorridos` (HU-04). 409 si ya hay uno en curso.
  Future<Recorrido> iniciar({
    required double latitud,
    required double longitud,
  }) => _recorrido(
    () => _dio.post<Map<String, dynamic>>(
      '/recorridos',
      data: {'lat_inicio': latitud, 'lon_inicio': longitud},
    ),
  );

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
