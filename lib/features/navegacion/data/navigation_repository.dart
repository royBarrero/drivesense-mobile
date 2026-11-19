import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/route_plan.dart';

/// Llamadas a `/navegacion` del backend (HU-30). El backend consulta a
/// OpenRouteService: la app nunca tiene la clave del proveedor.
///
/// Lanza [ErrorNavegacion] si el backend no pudo dar la ruta o los lugares, y
/// `ErrorApi` en los demás errores (p. ej. 401, que cierra la sesión).
class NavegacionRepositorio {
  NavegacionRepositorio(this._dio);

  final Dio _dio;

  /// `GET /navegacion/ruta`: ruta en auto de [origen] a [destino].
  Future<RutaPlaneada> ruta(Coordenada origen, Coordenada destino) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/navegacion/ruta',
        queryParameters: {
          'origen_lat': origen.latitud,
          'origen_lon': origen.longitud,
          'destino_lat': destino.latitud,
          'destino_lon': destino.longitud,
        },
      );
      return RutaPlaneada.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw traducirError(ErrorApi.desde(e));
    }
  }

  /// `GET /navegacion/lugares?q=`: lugares de Bolivia, primero los de Santa
  /// Cruz. Solo se llama al enviar la búsqueda (sin autocompletar).
  Future<List<Lugar>> lugares(String texto) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/navegacion/lugares',
        queryParameters: {'q': texto.trim()},
      );
      return [
        for (final lugar in respuesta.data!['lugares'] as List<dynamic>)
          Lugar.fromJson(lugar as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw traducirError(ErrorApi.desde(e));
    }
  }
}

/// Error de la navegación según el `codigo` del backend; los demás (401, 422)
/// siguen como `ErrorApi`.
Exception traducirError(ErrorApi error) {
  final motivo = switch (error.clave) {
    'sin_ruta' => MotivoErrorNavegacion.sinRuta,
    'sin_cuota' => MotivoErrorNavegacion.sinCuota,
    'navegacion_desactivada' ||
    'proveedor_caido' => MotivoErrorNavegacion.noDisponible,
    _ when error.codigo == null || (error.codigo ?? 0) >= 500 =>
      MotivoErrorNavegacion.sinConexion,
    _ => null,
  };
  if (motivo == null) return error;
  final mensaje = motivo == MotivoErrorNavegacion.sinConexion
      ? 'Revisa tu conexión a internet e intenta de nuevo.'
      : error.mensaje;
  return ErrorNavegacion(motivo, mensaje);
}

final navegacionRepositorioProvider = Provider<NavegacionRepositorio>(
  (ref) => NavegacionRepositorio(ref.watch(clienteApiProvider)),
);
