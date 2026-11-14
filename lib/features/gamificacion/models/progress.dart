import '../../recorridos/models/trip_score.dart';

/// Nivel del conductor (HU-21): número, nombre y puntos para alcanzarlo.
class Nivel {
  const Nivel({
    required this.numero,
    required this.nombre,
    required this.puntos,
  });

  factory Nivel.fromJson(Map<String, dynamic> json) => Nivel(
    numero: json['numero'] as int,
    nombre: json['nombre'] as String,
    puntos: json['puntos'] as int,
  );

  final int numero;
  final String nombre;
  final int puntos;
}

/// Qué cuenta el progreso de un logro o de un desafío semanal.
enum TipoProgreso {
  /// Un solo viaje que cumpla la condición: 0 o 1.
  viaje,
  viajes,
  km,

  /// Viajes seguidos; el progreso es la racha actual.
  racha,

  /// Promedio semanal (solo el desafío "Promedio muy bueno", HU-22).
  promedio;

  static TipoProgreso desdeCodigo(String codigo) =>
      TipoProgreso.values.firstWhere(
        (tipo) => tipo.name == codigo,
        orElse: () => TipoProgreso.viaje,
      );
}

/// Logro con su progreso (`GET /gamificacion/progreso`). El nombre y la
/// descripción vienen del backend; el ícono lo pone la app (`estiloLogro`).
class Logro {
  const Logro({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    this.tipo = TipoProgreso.viaje,
    this.meta = 1,
    this.progreso = 0,
    this.desbloqueado = false,
    this.fechaDesbloqueo,
  });

  factory Logro.fromJson(Map<String, dynamic> json) => Logro(
    codigo: json['codigo'] as String,
    nombre: json['nombre'] as String,
    descripcion: json['descripcion'] as String,
    tipo: switch (json['tipo']) {
      final String codigo => TipoProgreso.desdeCodigo(codigo),
      _ => TipoProgreso.viaje,
    },
    meta: json['meta'] as int? ?? 1,
    progreso: json['progreso'] as int? ?? 0,
    desbloqueado: json['desbloqueado'] as bool? ?? false,
    fechaDesbloqueo: switch (json['fecha_desbloqueo']) {
      final String fecha => DateTime.parse(fecha).toLocal(),
      _ => null,
    },
  );

  final String codigo;
  final String nombre;
  final String descripcion;
  final TipoProgreso tipo;
  final int meta;
  final int progreso;
  final bool desbloqueado;
  final DateTime? fechaDesbloqueo;

  /// Lo que falta: "Te faltan 3 viajes", "63 de 100 km", "Racha actual: 3 de 5".
  String get faltante {
    final resta = meta - progreso;
    return switch (tipo) {
      TipoProgreso.viajes =>
        'Te ${resta == 1 ? 'falta 1 viaje' : 'faltan $resta viajes'}',
      TipoProgreso.km => '$progreso de $meta km',
      TipoProgreso.racha => 'Racha actual: $progreso de $meta',
      TipoProgreso.viaje || TipoProgreso.promedio => 'Aún no lo consigues',
    };
  }
}

/// `GET /gamificacion/progreso` (HU-21).
class ProgresoConductor {
  const ProgresoConductor({
    required this.puntos,
    required this.nivel,
    this.siguienteNivel,
    this.logros = const [],
  });

  factory ProgresoConductor.fromJson(Map<String, dynamic> json) =>
      ProgresoConductor(
        puntos: json['puntos'] as int,
        nivel: Nivel.fromJson(json['nivel'] as Map<String, dynamic>),
        siguienteNivel: switch (json['siguiente_nivel']) {
          final Map<String, dynamic> nivel => Nivel.fromJson(nivel),
          _ => null,
        },
        logros: [
          for (final logro in json['logros'] as List)
            Logro.fromJson(logro as Map<String, dynamic>),
        ],
      );

  final int puntos;
  final Nivel nivel;

  /// Nulo en el nivel máximo.
  final Nivel? siguienteNivel;
  final List<Logro> logros;

  int get desbloqueados => logros.where((l) => l.desbloqueado).length;

  /// Avance dentro del nivel actual, de 0 a 1 (1 en el máximo).
  double get avance {
    final siguiente = siguienteNivel;
    if (siguiente == null) return 1;
    return ((puntos - nivel.puntos) / (siguiente.puntos - nivel.puntos)).clamp(
      0,
      1,
    );
  }
}

/// Un desafío semanal que completó el viaje recién finalizado, con los puntos
/// que dio (HU-23). El backend manda también su `tipo`, que el resumen no usa.
class DesafioCompletado {
  const DesafioCompletado({
    required this.codigo,
    required this.nombre,
    required this.puntos,
    this.categoria,
  });

  factory DesafioCompletado.fromJson(Map<String, dynamic> json) =>
      DesafioCompletado(
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        puntos: json['puntos'] as int,
        categoria: switch (json['categoria']) {
          final String codigo =>
            CategoriaPuntaje.values.where((c) => c.name == codigo).firstOrNull,
          _ => null,
        },
      );

  final String codigo;
  final String nombre;
  final int puntos;

  /// Solo en el punto débil.
  final CategoriaPuntaje? categoria;
}

/// Lo que ganó el viaje recién finalizado (respuesta del PATCH, HU-21 y HU-23).
class RecompensaViaje {
  const RecompensaViaje({
    required this.puntos,
    required this.subioDeNivel,
    required this.nivel,
    this.logrosNuevos = const [],
    this.desafiosCompletados = const [],
    this.bono,
  });

  /// Nula sin la clave o con `null` (descartado, versión anterior del backend).
  /// Sin `desafios_completados` ni `bono_semanal` (backend anterior a HU-23),
  /// quedan vacíos.
  static RecompensaViaje? fromJson(Object? json) => switch (json) {
    final Map<String, dynamic> datos => RecompensaViaje(
      puntos: datos['puntos'] as int,
      subioDeNivel: datos['subio_de_nivel'] as bool,
      nivel: Nivel.fromJson(datos['nivel'] as Map<String, dynamic>),
      logrosNuevos: [
        for (final logro in datos['logros_nuevos'] as List)
          Logro.fromJson(logro as Map<String, dynamic>),
      ],
      desafiosCompletados: [
        for (final desafio
            in datos['desafios_completados'] as List? ?? const [])
          DesafioCompletado.fromJson(desafio as Map<String, dynamic>),
      ],
      bono: datos['bono_semanal'] as int?,
    ),
    _ => null,
  };

  /// Los del viaje (sin los de los desafíos ni el bono).
  final int puntos;

  /// Con los puntos del viaje, de los desafíos y del bono.
  final bool subioDeNivel;

  /// El nivel después del viaje.
  final Nivel nivel;

  /// Solo los que desbloqueó este viaje.
  final List<Logro> logrosNuevos;

  /// Los desafíos de la semana que completó este viaje.
  final List<DesafioCompletado> desafiosCompletados;

  /// Puntos del bono por completar los 3 desafíos de la semana; nulo si este
  /// viaje no lo dio.
  final int? bono;

  /// Todo lo ganado: viaje, desafíos y bono.
  int get puntosTotal =>
      puntos +
      desafiosCompletados.fold<int>(0, (suma, d) => suma + d.puntos) +
      (bono ?? 0);

  /// El resumen solo la muestra si hay algo que celebrar.
  bool get hayNovedades =>
      subioDeNivel || logrosNuevos.isNotEmpty || desafiosCompletados.isNotEmpty;
}
