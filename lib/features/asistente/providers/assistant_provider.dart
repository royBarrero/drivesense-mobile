import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../auth/providers/session_provider.dart';
import '../data/assistant_repository.dart';
import '../models/assistant_message.dart';

/// Conversación con el asistente de ayuda durante la sesión.
class EstadoAsistente {
  const EstadoAsistente({
    this.mensajes = const [],
    this.enviando = false,
    this.error,
  });

  final List<MensajeAsistente> mensajes;
  final bool enviando;

  /// Mensaje del último envío fallido; la pregunta queda en la lista para
  /// reintentarla.
  final String? error;

  EstadoAsistente copyWith({
    List<MensajeAsistente>? mensajes,
    bool? enviando,
    String? error,
  }) => EstadoAsistente(
    mensajes: mensajes ?? this.mensajes,
    enviando: enviando ?? this.enviando,
    error: error,
  );
}

/// La conversación se conserva mientras dure la sesión (al salir de la
/// pantalla y volver sigue ahí) y se borra al cerrar sesión.
class AsistenteNotifier extends Notifier<EstadoAsistente> {
  @override
  EstadoAsistente build() {
    // Otro usuario (o sin sesión): conversación nueva
    ref.watch(sesionProvider.select((s) => s.value?.id));
    return const EstadoAsistente();
  }

  /// Agrega la pregunta y pide la respuesta. No hace nada si está vacía o si
  /// ya espera una respuesta.
  Future<void> preguntar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || state.enviando) return;
    state = state.copyWith(
      mensajes: [
        ...state.mensajes,
        MensajeAsistente(rol: RolMensaje.usuario, texto: pregunta),
      ],
    );
    await _pedirRespuesta();
  }

  /// Vuelve a pedir la respuesta de la última pregunta tras un error.
  Future<void> reintentar() async {
    if (state.enviando || state.error == null) return;
    await _pedirRespuesta();
  }

  /// Borra la conversación.
  void nueva() {
    if (state.enviando) return;
    state = const EstadoAsistente();
  }

  Future<void> _pedirRespuesta() async {
    state = state.copyWith(enviando: true);
    final conversacion = state.mensajes;
    final repositorio = ref.read(asistenteRepositorioProvider);
    try {
      final respuesta = await conSesion(
        ref,
        () => repositorio.responder(conversacion),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        mensajes: [...state.mensajes, respuesta],
        enviando: false,
      );
    } on ErrorApi catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(enviando: false, error: e.mensaje);
    }
  }
}

final asistenteProvider = NotifierProvider<AsistenteNotifier, EstadoAsistente>(
  AsistenteNotifier.new,
);

/// Preguntas frecuentes para empezar (`[]` sin sesión o si fallan: la pantalla
/// funciona igual sin ellas).
final sugerenciasAsistenteProvider = FutureProvider<List<String>>((ref) async {
  final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
  if (usuarioId == null) return const [];
  try {
    return await conSesion(
      ref,
      ref.read(asistenteRepositorioProvider).sugerencias,
    );
  } on ErrorApi {
    return const [];
  }
}, retry: (intento, error) => null);
