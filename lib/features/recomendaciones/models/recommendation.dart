import '../../telemetria/models/event_detector.dart';

/// Recomendación de un viaje finalizado, generada en el backend con reglas
/// fijas: la principal (HU-18), del tipo de evento que más restó, y las
/// secundarias (HU-19), de los demás tipos.
class Recomendacion {
  const Recomendacion({
    required this.tipo,
    required this.titulo,
    required this.texto,
  });

  /// `null` si el JSON no la trae (en curso, descartado o viaje anterior a
  /// HU-15).
  static Recomendacion? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final codigo = json['tipo'] as String;
    return Recomendacion(
      tipo: codigo == codigoSinEventos ? null : TipoEvento.desdeCodigo(codigo),
      titulo: json['titulo'] as String,
      texto: json['texto'] as String,
    );
  }

  /// Secundarias (HU-19), en el orden del backend; vacía si no vienen (sin
  /// secundarias o una versión anterior del backend).
  static List<Recomendacion> listaDesdeJson(Object? json) => switch (json) {
    final List<dynamic> lista => [
      for (final item in lista) ?Recomendacion.fromJson(item),
    ],
    _ => const [],
  };

  static const codigoSinEventos = 'sin_eventos';

  /// Tipo de evento del consejo; `null` en el mensaje positivo (viaje sin
  /// eventos).
  final TipoEvento? tipo;
  final String titulo;
  final String texto;
}
