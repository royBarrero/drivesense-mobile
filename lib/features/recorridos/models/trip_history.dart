import '../../telemetria/models/event_detector.dart';
import '../../telemetria/models/route.dart';
import 'trip_score.dart';

/// Recorrido finalizado del historial (`RecorridoHistorial` del backend, HU-06).
class RecorridoHistorial {
  const RecorridoHistorial({
    required this.id,
    required this.salida,
    required this.llegada,
    required this.distanciaM,
    required this.duracionS,
    required this.velocidadMaximaKmh,
    required this.velocidadPromedioKmh,
    this.drivescore,
    this.puntaje,
    this.eventosPorTipo,
    this.ruta,
    this.eventos,
  });

  factory RecorridoHistorial.fromJson(Map<String, dynamic> json) =>
      RecorridoHistorial(
        id: json['id'] as int,
        salida: DateTime.parse(json['fecha_inicio'] as String).toLocal(),
        llegada: DateTime.parse(json['fecha_fin'] as String).toLocal(),
        distanciaM: (json['distancia_m'] as num).toDouble(),
        duracionS: json['duracion_s'] as int,
        velocidadMaximaKmh: (json['velocidad_maxima_kmh'] as num).toDouble(),
        velocidadPromedioKmh: (json['velocidad_promedio_kmh'] as num)
            .toDouble(),
        drivescore: json['drivescore'] as int?,
        // El listado trae solo el DriveScore; las categorías, solo el detalle
        puntaje: json.containsKey('puntaje_frenadas')
            ? PuntajeViaje.fromJson(json)
            : null,
        eventosPorTipo: switch (json['eventos_por_tipo']) {
          final Map<String, dynamic> conteo => {
            for (final MapEntry(:key, :value) in conteo.entries)
              TipoEvento.desdeCodigo(key): value as int,
          },
          _ => null,
        },
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

  final int id;

  /// `fecha_inicio` y `fecha_fin`, en la zona horaria del teléfono.
  final DateTime salida;
  final DateTime llegada;

  final double distanciaM;
  final int duracionS;
  final double velocidadMaximaKmh;
  final double velocidadPromedioKmh;

  /// DriveScore del viaje; nulo en los anteriores a HU-15. Viene en el listado
  /// y en el detalle.
  final int? drivescore;

  /// DriveScore con sus categorías (HU-15): solo en el detalle
  /// (`GET /recorridos/{id}`).
  final PuntajeViaje? puntaje;

  /// Cuántos eventos hubo de cada tipo (HU-16): solo en el detalle y si el
  /// viaje tiene DriveScore.
  final Map<TipoEvento, int>? eventosPorTipo;

  /// Ruta GPS (HU-08): solo en el detalle; nula en los viajes sin ruta.
  final List<PuntoRuta>? ruta;

  /// Eventos de riesgo en orden cronológico, con su posición (HU-29): solo en
  /// el detalle y si el viaje tiene DriveScore.
  final List<EventoRiesgo>? eventos;
}

/// Totales de los viajes finalizados del periodo.
class ResumenPeriodo {
  const ResumenPeriodo({
    required this.viajes,
    required this.distanciaM,
    required this.duracionS,
  });

  factory ResumenPeriodo.fromJson(Map<String, dynamic> json) => ResumenPeriodo(
    viajes: json['viajes'] as int,
    distanciaM: (json['distancia_m'] as num).toDouble(),
    duracionS: json['duracion_s'] as int,
  );

  final int viajes;
  final double distanciaM;
  final int duracionS;
}

/// Página de `GET /recorridos`.
class PaginaHistorial {
  const PaginaHistorial({
    required this.recorridos,
    required this.siguiente,
    required this.resumen,
  });

  factory PaginaHistorial.fromJson(Map<String, dynamic> json) =>
      PaginaHistorial(
        recorridos: [
          for (final recorrido in json['recorridos'] as List)
            RecorridoHistorial.fromJson(recorrido as Map<String, dynamic>),
        ],
        siguiente: json['siguiente'] as int?,
        resumen: json['resumen'] == null
            ? null
            : ResumenPeriodo.fromJson(json['resumen'] as Map<String, dynamic>),
      );

  final List<RecorridoHistorial> recorridos;

  /// Cursor de la página siguiente (`antes_de`); nulo si no hay más.
  final int? siguiente;

  /// Solo en la primera página.
  final ResumenPeriodo? resumen;
}

/// Filtro del historial. "Esta semana" y "este mes" dependen de la zona del teléfono.
enum PeriodoHistorial {
  semana('Esta semana'),
  mes('Este mes'),
  todos('Todos');

  const PeriodoHistorial(this.texto);

  final String texto;

  /// Inicio del periodo (medianoche local del lunes o del día 1); nulo = todos.
  DateTime? desde(DateTime ahora) {
    final local = ahora.toLocal();
    return switch (this) {
      semana => DateTime(
        local.year,
        local.month,
        local.day - local.weekday + 1,
      ),
      mes => DateTime(local.year, local.month),
      todos => null,
    };
  }
}
