import 'package:dio/dio.dart';

/// Error de un campo en una respuesta 422.
class ErrorCampo {
  const ErrorCampo({required this.campo, required this.mensaje});

  /// Nombre del campo en la API (`email`, `administrador.telefono`...); puede ser nulo.
  final String? campo;
  final String mensaje;
}

/// Error de la API traducido a un tipo propio.
///
/// El `mensaje` es el `detail` que manda el backend, que ya viene en español.
class ErrorApi implements Exception {
  const ErrorApi({required this.mensaje, this.codigo, this.errores = const []});

  final String mensaje;

  /// Código HTTP; nulo si no hubo respuesta (sin conexión).
  final int? codigo;

  /// Solo en 422.
  final List<ErrorCampo> errores;

  static const sinConexion = 'No se pudo conectar con el servidor';

  // Único mensaje propio: el backend no manda `detail` (p. ej. un 500)
  static const inesperado = 'Ocurrió un error inesperado. Intenta de nuevo.';

  factory ErrorApi.desde(DioException e) {
    final respuesta = e.response;
    if (respuesta == null) {
      return const ErrorApi(mensaje: sinConexion);
    }

    final datos = respuesta.data;
    final detail = datos is Map ? datos['detail'] : null;
    if (detail is! String) {
      return ErrorApi(mensaje: inesperado, codigo: respuesta.statusCode);
    }

    final errores = <ErrorCampo>[
      if (datos is Map && datos['errores'] is List)
        for (final error in datos['errores'] as List)
          if (error is Map)
            ErrorCampo(
              campo: error['campo'] as String?,
              mensaje: '${error['mensaje']}',
            ),
    ];
    return ErrorApi(
      mensaje: detail,
      codigo: respuesta.statusCode,
      errores: errores,
    );
  }

  /// Mensaje de la API para un campo concreto (422), o nulo.
  String? mensajeDeCampo(String campo) {
    for (final error in errores) {
      if (error.campo == campo) return error.mensaje;
    }
    return null;
  }

  @override
  String toString() => 'ErrorApi($codigo): $mensaje';
}
