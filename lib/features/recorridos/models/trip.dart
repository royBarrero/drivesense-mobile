import 'trip_accumulator.dart';

/// `en_curso` | `finalizado` | `descartado` (enum `EstadoRecorrido` del backend).
enum EstadoRecorrido {
  enCurso('en_curso'),
  finalizado('finalizado'),
  descartado('descartado');

  const EstadoRecorrido(this.valorApi);

  final String valorApi;

  static EstadoRecorrido desdeApi(String valor) =>
      values.firstWhere((estado) => estado.valorApi == valor);
}

/// Recorrido tal como lo devuelve `RecorridoSalida` del backend (solo lo que usa la app).
class Recorrido {
  const Recorrido({
    required this.id,
    required this.estado,
    required this.fechaInicio,
  });

  factory Recorrido.fromJson(Map<String, dynamic> json) => Recorrido(
    id: json['id'] as int,
    estado: EstadoRecorrido.desdeApi(json['estado'] as String),
    fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
  );

  final int id;
  final EstadoRecorrido estado;

  /// Hora del servidor. `fecha_fin` debe ser posterior a esta.
  final DateTime fechaInicio;
}

/// Recorrido en curso guardado en el teléfono con sus acumulados.
class ViajeActivo {
  const ViajeActivo({
    required this.recorridoId,
    required this.fechaInicioServidor,
    required this.acumulador,
  });

  factory ViajeActivo.fromJson(Map<String, dynamic> json) => ViajeActivo(
    recorridoId: json['recorrido_id'] as int,
    fechaInicioServidor: DateTime.parse(
      json['fecha_inicio_servidor'] as String,
    ),
    acumulador: AcumuladorRecorrido.fromJson(
      json['acumulador'] as Map<String, dynamic>,
    ),
  );

  final int recorridoId;
  final DateTime fechaInicioServidor;
  final AcumuladorRecorrido acumulador;

  Map<String, dynamic> toJson() => {
    'recorrido_id': recorridoId,
    'fecha_inicio_servidor': fechaInicioServidor.toUtc().toIso8601String(),
    'acumulador': acumulador.toJson(),
  };
}

/// Resumen que se envía al finalizar (`PATCH /recorridos/{id}/finalizar`).
///
/// Se guarda en el teléfono hasta que el backend lo recibe.
class ResumenRecorrido {
  const ResumenRecorrido({
    required this.recorridoId,
    required this.fechaFin,
    required this.distanciaM,
    required this.duracionS,
    required this.velocidadMaximaKmh,
    required this.velocidadPromedioKmh,
    required this.latitudFin,
    required this.longitudFin,
  });

  /// Arma el resumen con los acumulados del viaje, llegando en [llegada] a la hora [fechaFin].
  factory ResumenRecorrido.desde(
    ViajeActivo viaje, {
    required DateTime fechaFin,
    required Lectura llegada,
  }) {
    // El backend exige fecha_fin > fecha_inicio (hora del servidor): cubre
    // un reloj del teléfono atrasado
    final minimo = viaje.fechaInicioServidor.add(const Duration(seconds: 1));
    final fin = fechaFin.isAfter(minimo) ? fechaFin : minimo;
    final acumulador = viaje.acumulador;
    final duracion = acumulador.duracionS(fin);
    return ResumenRecorrido(
      recorridoId: viaje.recorridoId,
      fechaFin: fin,
      distanciaM: acumulador.distanciaM,
      duracionS: duracion,
      velocidadMaximaKmh: acumulador.velocidadMaximaKmh,
      velocidadPromedioKmh: acumulador.velocidadPromedioKmh(duracion),
      latitudFin: llegada.latitud,
      longitudFin: llegada.longitud,
    );
  }

  factory ResumenRecorrido.fromJson(Map<String, dynamic> json) =>
      ResumenRecorrido(
        recorridoId: json['recorrido_id'] as int,
        fechaFin: DateTime.parse(json['fecha_fin'] as String),
        distanciaM: (json['distancia_m'] as num).toDouble(),
        duracionS: json['duracion_s'] as int,
        velocidadMaximaKmh: (json['velocidad_maxima_kmh'] as num).toDouble(),
        velocidadPromedioKmh: (json['velocidad_promedio_kmh'] as num)
            .toDouble(),
        latitudFin: (json['lat_fin'] as num).toDouble(),
        longitudFin: (json['lon_fin'] as num).toDouble(),
      );

  final int recorridoId;
  final DateTime fechaFin;
  final double distanciaM;
  final int duracionS;
  final double velocidadMaximaKmh;
  final double velocidadPromedioKmh;
  final double latitudFin;
  final double longitudFin;

  /// Cuerpo del `PATCH` (la fecha con zona horaria, en UTC).
  Map<String, dynamic> toApiJson() => {
    'fecha_fin': fechaFin.toUtc().toIso8601String(),
    'distancia_m': distanciaM,
    'duracion_s': duracionS,
    'velocidad_maxima_kmh': velocidadMaximaKmh,
    'velocidad_promedio_kmh': velocidadPromedioKmh,
    'lat_fin': latitudFin,
    'lon_fin': longitudFin,
  };

  Map<String, dynamic> toJson() => {
    'recorrido_id': recorridoId,
    ...toApiJson(),
  };
}
