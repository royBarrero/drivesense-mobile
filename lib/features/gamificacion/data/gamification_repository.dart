import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../puntaje/data/score_repository.dart';
import '../models/progress.dart';
import '../models/weekly_challenges.dart';

/// Llamadas a `/gamificacion` del backend. Lanza `ErrorApi` si la petición falla.
class GamificacionRepositorio {
  GamificacionRepositorio(this._dio);

  final Dio _dio;

  /// `GET /gamificacion/progreso` (HU-21): nivel, puntos y logros.
  Future<ProgresoConductor> progreso() async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/gamificacion/progreso',
      );
      return ProgresoConductor.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  /// `GET /gamificacion/desafios` (HU-22): los 3 desafíos de la semana.
  /// `desde` es el lunes 00:00 local y va **con la zona del teléfono**: el
  /// backend la usa para fijar la semana la primera vez.
  Future<DesafiosSemana> desafios({required DateTime desde}) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/gamificacion/desafios',
        queryParameters: {'desde': isoConZona(desde)},
      );
      return DesafiosSemana.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

final gamificacionRepositorioProvider = Provider<GamificacionRepositorio>(
  (ref) => GamificacionRepositorio(ref.watch(clienteApiProvider)),
);
