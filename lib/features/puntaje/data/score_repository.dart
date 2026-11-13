import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/period_comparison.dart';
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

  /// `GET /puntaje/comparativo` (HU-20): el periodo que empieza en [desde]
  /// frente al anterior.
  Future<ComparativoPuntaje> comparativo({
    required PeriodoComparativo periodo,
    required DateTime desde,
  }) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/puntaje/comparativo',
        // Con la zona del teléfono, no en UTC: el backend comprueba que sea
        // el lunes o el día 1 a medianoche y calcula el periodo anterior
        queryParameters: {'periodo': periodo.name, 'desde': isoConZona(desde)},
      );
      return ComparativoPuntaje.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

/// `2026-11-09T00:00:00-05:00`: la hora local con su zona (`toIso8601String`
/// de una fecha local no la incluye).
String isoConZona(DateTime fecha) {
  final local = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  final zona = local.timeZoneOffset;
  final minutos = zona.inMinutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${dos(local.month)}-'
      '${dos(local.day)}T${dos(local.hour)}:${dos(local.minute)}:'
      '${dos(local.second)}${zona.isNegative ? '-' : '+'}'
      '${dos(minutos ~/ 60)}:${dos(minutos % 60)}';
}

final puntajeRepositorioProvider = Provider<PuntajeRepositorio>(
  (ref) => PuntajeRepositorio(ref.watch(clienteApiProvider)),
);
