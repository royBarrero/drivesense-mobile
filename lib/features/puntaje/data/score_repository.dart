import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/score_history.dart';

/// Llamadas a `/puntaje` del backend. Lanza `ErrorApi` si la petición falla.
class PuntajeRepositorio {
  PuntajeRepositorio(this._dio);

  final Dio _dio;

  /// `GET /puntaje/historico` (HU-17): desde [desde] hasta ahora.
  Future<HistoricoPuntaje> historico({required DateTime desde}) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/puntaje/historico',
        // En UTC: un instante con zona, que el backend exige
        queryParameters: {'desde': desde.toUtc().toIso8601String()},
      );
      return HistoricoPuntaje.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

final puntajeRepositorioProvider = Provider<PuntajeRepositorio>(
  (ref) => PuntajeRepositorio(ref.watch(clienteApiProvider)),
);
