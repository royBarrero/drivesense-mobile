/// Quién escribió el mensaje del asistente de ayuda.
enum RolMensaje {
  usuario('usuario'),
  asistente('asistente');

  const RolMensaje(this.codigo);

  /// Código de la API.
  final String codigo;
}

/// Mensaje de la conversación con el asistente de ayuda. La conversación vive
/// en el teléfono: el backend no la guarda.
class MensajeAsistente {
  const MensajeAsistente({
    required this.rol,
    required this.texto,
    this.generadaPorIa = false,
  });

  /// Respuesta de `POST /asistente/mensajes`.
  factory MensajeAsistente.respuesta(Map<String, dynamic> json) =>
      MensajeAsistente(
        rol: RolMensaje.asistente,
        texto: json['texto'] as String,
        generadaPorIa: json['generada_por_ia'] as bool? ?? false,
      );

  final RolMensaje rol;
  final String texto;

  /// La redactó la IA; falso en las respuestas fijas de las preguntas
  /// frecuentes (sin la cápsula "Con IA").
  final bool generadaPorIa;

  bool get esDelUsuario => rol == RolMensaje.usuario;

  Map<String, dynamic> toApiJson() => {'rol': rol.codigo, 'texto': texto};
}
