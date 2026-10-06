import '../../telemetria/models/event_detector.dart';

/// DriveScore del viaje y su puntaje por categoría (HU-15), de 0 a 100. Lo
/// calcula el backend al finalizar.
class PuntajeViaje {
  const PuntajeViaje({
    required this.drivescore,
    required this.frenadas,
    required this.aceleraciones,
    required this.giros,
    required this.velocidad,
  });

  /// `null` si la respuesta no trae puntaje (en curso, descartado o un viaje
  /// finalizado antes de que existiera).
  static PuntajeViaje? fromJson(Map<String, dynamic> json) {
    final drivescore = json['drivescore'] as int?;
    if (drivescore == null) return null;
    return PuntajeViaje(
      drivescore: drivescore,
      frenadas: json['puntaje_frenadas'] as int,
      aceleraciones: json['puntaje_aceleraciones'] as int,
      giros: json['puntaje_giros'] as int,
      velocidad: json['puntaje_velocidad'] as int,
    );
  }

  final int drivescore;
  final int frenadas;
  final int aceleraciones;
  final int giros;
  final int velocidad;

  Calificacion get calificacion => Calificacion.de(drivescore);

  int de(CategoriaPuntaje categoria) => switch (categoria) {
    CategoriaPuntaje.frenadas => frenadas,
    CategoriaPuntaje.aceleraciones => aceleraciones,
    CategoriaPuntaje.giros => giros,
    CategoriaPuntaje.velocidad => velocidad,
  };

  /// "Lo que más restó" (HU-16): la categoría con menor puntaje; en empate, la
  /// de mayor peso y, con el mismo peso, la primera de [CategoriaPuntaje].
  /// `null` si ninguna bajó de 100.
  CategoriaPuntaje? get masResto {
    CategoriaPuntaje? peor;
    for (final categoria in CategoriaPuntaje.values) {
      final puntaje = de(categoria);
      if (puntaje >= 100) continue;
      if (peor == null ||
          puntaje < de(peor) ||
          (puntaje == de(peor) && categoria.peso > peor.peso)) {
        peor = categoria;
      }
    }
    return peor;
  }
}

/// Categorías del DriveScore (HU-16), en el orden del desglose, con su peso en
/// la fórmula del backend y el tipo de evento que las resta.
enum CategoriaPuntaje {
  frenadas('Frenadas', 'frenadas', 0.30, TipoEvento.frenadaBrusca),
  aceleraciones(
    'Aceleraciones',
    'aceleraciones',
    0.20,
    TipoEvento.aceleracionSevera,
  ),
  giros('Giros', 'giros', 0.20, TipoEvento.giroAgresivo),
  velocidad('Velocidad', 'velocidad', 0.30, TipoEvento.excesoVelocidad);

  const CategoriaPuntaje(this.nombre, this.enTexto, this.peso, this.tipo);

  final String nombre;

  /// En "Lo que más restó: frenadas".
  final String enTexto;
  final double peso;
  final TipoEvento tipo;

  /// "Sin eventos", "1 frenada", "2 frenadas"…
  String eventos(int cantidad) {
    if (cantidad == 0) return 'Sin eventos';
    final (singular, plural) = switch (this) {
      frenadas => ('frenada', 'frenadas'),
      aceleraciones => ('aceleración', 'aceleraciones'),
      giros => ('giro', 'giros'),
      velocidad => ('exceso', 'excesos'),
    };
    return '$cantidad ${cantidad == 1 ? singular : plural}';
  }
}

/// Calificación del DriveScore.
enum Calificacion {
  excelente('Excelente'),
  muyBueno('Muy bueno'),
  regular('Regular'),
  riesgoso('Riesgoso');

  const Calificacion(this.texto);

  final String texto;

  /// Código del backend (histórico, HU-17): `excelente`, `muy_bueno`…
  static Calificacion desdeCodigo(String codigo) => switch (codigo) {
    'excelente' => excelente,
    'muy_bueno' => muyBueno,
    'regular' => regular,
    _ => riesgoso,
  };

  /// Excelente 90–100, Muy bueno 75–89, Regular 60–74, Riesgoso < 60.
  static Calificacion de(int drivescore) => switch (drivescore) {
    >= 90 => excelente,
    >= 75 => muyBueno,
    >= 60 => regular,
    _ => riesgoso,
  };
}
