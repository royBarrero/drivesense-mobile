import '../../telemetria/models/event_detector.dart';
import '../../telemetria/models/route.dart';
import 'trip_accumulator.dart';
import 'trip_score.dart';

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
    this.puntaje,
  });

  factory Recorrido.fromJson(Map<String, dynamic> json) => Recorrido(
    id: json['id'] as int,
    estado: EstadoRecorrido.desdeApi(json['estado'] as String),
    fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
    puntaje: PuntajeViaje.fromJson(json),
  );

  final int id;
  final EstadoRecorrido estado;

  /// Hora del servidor. `fecha_fin` debe ser posterior a esta.
  final DateTime fechaInicio;

  /// DriveScore (HU-15): solo en la respuesta de un recorrido finalizado.
  final PuntajeViaje? puntaje;
}

/// Recorrido en curso guardado en el teléfono con sus acumulados y su ruta.
///
/// La ruta no va en [toJson]: se guarda en un archivo aparte
/// (`AlmacenRecorrido`), agregando solo los puntos nuevos.
class ViajeActivo {
  ViajeActivo({
    required this.recorridoId,
    required this.fechaInicioServidor,
    required this.acumulador,
    ConstructorRuta? ruta,
    this.sinGiroscopio = false,
    List<EventoRiesgo>? eventos,
  }) : ruta = ruta ?? ConstructorRuta(),
       eventos = eventos ?? [];

  factory ViajeActivo.fromJson(
    Map<String, dynamic> json, {
    List<PuntoRuta> ruta = const [],
  }) => ViajeActivo(
    recorridoId: json['recorrido_id'] as int,
    fechaInicioServidor: DateTime.parse(
      json['fecha_inicio_servidor'] as String,
    ),
    acumulador: AcumuladorRecorrido.fromJson(
      json['acumulador'] as Map<String, dynamic>,
    ),
    ruta: ConstructorRuta(ruta),
    sinGiroscopio: json['sin_giroscopio'] as bool? ?? false,
    eventos: [
      for (final evento in json['eventos'] as List<dynamic>? ?? [])
        EventoRiesgo.fromJson(evento as Map<String, dynamic>),
    ],
  );

  final int recorridoId;
  final DateTime fechaInicioServidor;
  final AcumuladorRecorrido acumulador;
  final ConstructorRuta ruta;

  /// El teléfono no tiene giroscopio: viaje sin detección de giros (HU-07).
  bool sinGiroscopio;

  /// Eventos de riesgo detectados (HU-10). Por ahora solo en el teléfono: no
  /// van en el resumen.
  final List<EventoRiesgo> eventos;

  /// Agrega [evento] o, si es la actualización de uno ya registrado (mismo
  /// tipo y fecha, como el exceso de velocidad mientras dura), lo reemplaza.
  /// `true` si es nuevo.
  bool registrarEvento(EventoRiesgo evento) {
    final i = eventos.indexWhere(
      (e) => e.tipo == evento.tipo && e.fecha == evento.fecha,
    );
    if (i == -1) {
      eventos.add(evento);
      return true;
    }
    eventos[i] = evento;
    return false;
  }

  /// Cierra los eventos que seguían abiertos (al terminar el viaje o al
  /// continuar uno interrumpido), con lo acumulado hasta ahora.
  void cerrarEventosEnCurso() {
    for (var i = 0; i < eventos.length; i++) {
      if (eventos[i].enCurso) eventos[i] = eventos[i].cerrado();
    }
  }

  Map<String, dynamic> toJson() => {
    'recorrido_id': recorridoId,
    'fecha_inicio_servidor': fechaInicioServidor.toUtc().toIso8601String(),
    'acumulador': acumulador.toJson(),
    'sin_giroscopio': sinGiroscopio,
    'eventos': eventos,
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
    this.ruta,
    this.eventos,
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
      ruta: viaje.ruta.puntos,
      // Ya cerrados al finalizar (un exceso abierto queda con lo acumulado)
      eventos: List.of(viaje.eventos),
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
        ruta: switch (json['ruta']) {
          final List<dynamic> puntos => [
            for (final punto in puntos)
              PuntoRuta.fromJson(punto as Map<String, dynamic>),
          ],
          _ => null,
        },
        eventos: switch (json['eventos']) {
          final List<dynamic> eventos => [
            for (final evento in eventos)
              EventoRiesgo.desdeApi(evento as Map<String, dynamic>),
          ],
          _ => null,
        },
      );

  final int recorridoId;
  final DateTime fechaFin;
  final double distanciaM;
  final int duracionS;
  final double velocidadMaximaKmh;
  final double velocidadPromedioKmh;
  final double latitudFin;
  final double longitudFin;

  /// Puntos de la ruta (HU-08). Nula en un resumen guardado por una versión
  /// anterior de la app: se envía sin el campo.
  final List<PuntoRuta>? ruta;

  /// Eventos de riesgo (HU-15), que el backend usa para el DriveScore. Nulos en
  /// un resumen guardado por una versión anterior de la app: se envía sin el
  /// campo.
  final List<EventoRiesgo>? eventos;

  /// Cuerpo del `PATCH` (la fecha con zona horaria, en UTC).
  Map<String, dynamic> toApiJson() => {
    'fecha_fin': fechaFin.toUtc().toIso8601String(),
    'distancia_m': distanciaM,
    'duracion_s': duracionS,
    'velocidad_maxima_kmh': velocidadMaximaKmh,
    'velocidad_promedio_kmh': velocidadPromedioKmh,
    'lat_fin': latitudFin,
    'lon_fin': longitudFin,
    'ruta': ?ruta?.map((punto) => punto.toJson()).toList(),
    'eventos': ?eventos?.map((evento) => evento.toApiJson()).toList(),
  };

  Map<String, dynamic> toJson() => {
    'recorrido_id': recorridoId,
    ...toApiJson(),
  };
}
