import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/assistant_message.dart';

/// Como mucho estos mensajes por pregunta (el tope del backend): los más
/// recientes.
const maximoMensajesEnviados = 20;

/// Llamadas a `/asistente` del backend. Lanza `ErrorApi` si la petición falla.
class AsistenteRepositorio {
  AsistenteRepositorio(this._dio);

  final Dio _dio;

  /// `GET /asistente/sugerencias`: preguntas frecuentes para empezar.
  Future<List<String>> sugerencias() async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/asistente/sugerencias',
      );
      return [
        for (final s in respuesta.data!['sugerencias'] as List<dynamic>)
          s as String,
      ];
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  /// `POST /asistente/mensajes`: la respuesta a la última pregunta de
  /// [conversacion] (se envían los últimos [maximoMensajesEnviados]).
  Future<MensajeAsistente> responder(
    List<MensajeAsistente> conversacion,
  ) async {
    final recientes = conversacion.length > maximoMensajesEnviados
        ? conversacion.sublist(conversacion.length - maximoMensajesEnviados)
        : conversacion;
    try {
      final respuesta = await _dio.post<Map<String, dynamic>>(
        '/asistente/mensajes',
        data: {
          'mensajes': [for (final m in recientes) m.toApiJson()],
        },
      );
      return MensajeAsistente.respuesta(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

final asistenteRepositorioProvider = Provider<AsistenteRepositorio>(
  (ref) => AsistenteRepositorio(ref.watch(clienteApiProvider)),
);
