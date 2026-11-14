import '../../recorridos/models/trip_score.dart';
import 'progress.dart';

/// Tipo de desafío: cada semana hay uno de cada uno (HU-22).
enum TipoDesafio {
  constancia('Constancia'),
  calidad('Calidad'),
  puntoDebil('Tu punto débil');

  const TipoDesafio(this.etiqueta);

  final String etiqueta;

  static TipoDesafio desdeCodigo(String codigo) => switch (codigo) {
    'calidad' => calidad,
    'punto_debil' => puntoDebil,
    _ => constancia,
  };
}

/// Un desafío de la semana con su avance (`GET /gamificacion/desafios`). Todo
/// lo calcula el backend; la app arma los textos.
class Desafio {
  const Desafio({
    required this.codigo,
    required this.tipo,
    required this.nombre,
    required this.descripcion,
    required this.tipoProgreso,
    required this.meta,
    required this.progreso,
    required this.completado,
    required this.puntos,
    this.categoria,
    this.promedio,
    this.viajes,
    this.viajesMinimos,
  });

  factory Desafio.fromJson(Map<String, dynamic> json) => Desafio(
    codigo: json['codigo'] as String,
    tipo: TipoDesafio.desdeCodigo(json['tipo'] as String),
    nombre: json['nombre'] as String,
    descripcion: json['descripcion'] as String,
    tipoProgreso: TipoProgreso.desdeCodigo(json['tipo_progreso'] as String),
    meta: json['meta'] as int,
    progreso: json['progreso'] as int,
    completado: json['completado'] as bool,
    puntos: json['puntos'] as int,
    categoria: switch (json['categoria']) {
      final String codigo =>
        CategoriaPuntaje.values.where((c) => c.name == codigo).firstOrNull,
      _ => null,
    },
    promedio: json['promedio'] as int?,
    viajes: json['viajes'] as int?,
    viajesMinimos: json['viajes_minimos'] as int?,
  );

  final String codigo;
  final TipoDesafio tipo;
  final String nombre;
  final String descripcion;
  final TipoProgreso tipoProgreso;
  final int meta;

  /// Hasta la meta; en la racha, la actual; en el promedio, el promedio actual.
  final int progreso;

  /// Una vez cumplido no se pierde en la semana.
  final bool completado;

  /// Recompensa al completarlo (se entrega en la HU-23).
  final int puntos;

  /// Solo en el punto débil.
  final CategoriaPuntaje? categoria;

  /// Solo en "Promedio muy bueno": el promedio de la semana (nulo sin viajes),
  /// los viajes que lleva y los que pide.
  final int? promedio;
  final int? viajes;
  final int? viajesMinimos;

  bool get _faltanViajes => (viajes ?? 0) < (viajesMinimos ?? 0);

  /// "2 de 5 viajes", "34 de 50 km", "Racha actual: 1 de 3",
  /// "Promedio 76 · 2 de 3 viajes", "Promedio 76 · meta 80".
  String get avanceTexto => switch (tipoProgreso) {
    TipoProgreso.viajes || TipoProgreso.viaje =>
      '$progreso de $meta ${meta == 1 ? 'viaje' : 'viajes'}',
    TipoProgreso.km => '$progreso de $meta km',
    TipoProgreso.racha => 'Racha actual: $progreso de $meta',
    TipoProgreso.promedio => switch (promedio) {
      null => '${viajes ?? 0} de ${viajesMinimos ?? 0} viajes',
      final p when _faltanViajes =>
        'Promedio $p · $viajes de $viajesMinimos viajes',
      final p => 'Promedio $p · meta $meta',
    },
  };

  /// De 0 a 1. En el promedio, mientras faltan viajes, cuenta los viajes.
  double get avance {
    if (completado) return 1;
    if (meta <= 0) return 0;
    if (tipoProgreso == TipoProgreso.promedio && _faltanViajes) {
      return (viajes ?? 0) / viajesMinimos!;
    }
    return (progreso / meta).clamp(0, 1);
  }
}

/// Bono por completar los 3 desafíos de la semana (HU-23).
class BonoSemana {
  const BonoSemana({this.puntos = 100, this.recibido = false});

  /// Sin la clave (backend anterior a HU-23): 100 pts, sin recibir.
  factory BonoSemana.fromJson(Object? json) => switch (json) {
    final Map<String, dynamic> datos => BonoSemana(
      puntos: datos['puntos'] as int,
      recibido: datos['recibido'] as bool,
    ),
    _ => const BonoSemana(),
  };

  final int puntos;
  final bool recibido;
}

/// Los 3 desafíos de la semana en curso (constancia, calidad, punto débil).
class DesafiosSemana {
  const DesafiosSemana({
    required this.inicio,
    required this.fin,
    required this.desafios,
    this.bono = const BonoSemana(),
  });

  factory DesafiosSemana.fromJson(Map<String, dynamic> json) => DesafiosSemana(
    inicio: DateTime.parse(json['inicio'] as String).toLocal(),
    fin: DateTime.parse(json['fin'] as String).toLocal(),
    desafios: [
      for (final desafio in json['desafios'] as List)
        Desafio.fromJson(desafio as Map<String, dynamic>),
    ],
    bono: BonoSemana.fromJson(json['bono']),
  );

  final DateTime inicio;
  final DateTime fin;
  final List<Desafio> desafios;
  final BonoSemana bono;

  int get completados => desafios.where((d) => d.completado).length;

  /// "Quedan 3 días", "Queda 1 día", "Quedan 5 h", "Queda menos de 1 h".
  String tiempoRestante(DateTime ahora) {
    final resta = fin.difference(ahora);
    if (resta <= Duration.zero) return 'La semana terminó';
    if (resta.inDays >= 1) {
      return resta.inDays == 1 ? 'Queda 1 día' : 'Quedan ${resta.inDays} días';
    }
    if (resta.inHours >= 1) return 'Quedan ${resta.inHours} h';
    return 'Queda menos de 1 h';
  }
}
