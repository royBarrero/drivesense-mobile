import '../../recorridos/models/trip_score.dart';

/// Periodos de "Mi DriveScore" (HU-17). Inicio usa el de 7 días.
enum PeriodoPuntaje {
  dias7('7 días', 7),
  dias30('30 días', 30),
  meses3('3 meses', 90);

  const PeriodoPuntaje(this.texto, this.dias);

  final String texto;

  /// Días del periodo, contando hoy.
  final int dias;

  /// Medianoche local de hace `dias − 1` días: el periodo termina ahora.
  DateTime desde(DateTime ahora) {
    final local = ahora.toLocal();
    return DateTime(local.year, local.month, local.day - (dias - 1));
  }
}

/// Punto del gráfico: un viaje, o el promedio de un día o una semana.
class PuntoHistorico {
  const PuntoHistorico({
    required this.fecha,
    required this.drivescore,
    required this.viajes,
  });

  factory PuntoHistorico.fromJson(Map<String, dynamic> json) => PuntoHistorico(
    fecha: DateTime.parse(json['fecha'] as String).toLocal(),
    drivescore: json['drivescore'] as int,
    viajes: json['viajes'] as int,
  );

  final DateTime fecha;
  final int drivescore;
  final int viajes;
}

/// Promedio de una categoría y su cambio frente al periodo anterior.
class PromedioCategoria {
  const PromedioCategoria({required this.promedio, this.diferencia});

  factory PromedioCategoria.fromJson(Map<String, dynamic> json) =>
      PromedioCategoria(
        promedio: json['promedio'] as int,
        diferencia: json['diferencia'] as int?,
      );

  final int promedio;

  /// Nula si el periodo anterior no tiene viajes.
  final int? diferencia;
}

/// Mejor o peor viaje del periodo; `id` abre su detalle.
class ViajeDestacado {
  const ViajeDestacado({
    required this.id,
    required this.fecha,
    required this.distanciaM,
    required this.drivescore,
  });

  factory ViajeDestacado.fromJson(Map<String, dynamic> json) => ViajeDestacado(
    id: json['id'] as int,
    fecha: DateTime.parse(json['fecha_inicio'] as String).toLocal(),
    distanciaM: (json['distancia_m'] as num).toDouble(),
    drivescore: json['drivescore'] as int,
  );

  final int id;
  final DateTime fecha;
  final double distanciaM;
  final int drivescore;
}

/// `GET /puntaje/historico` (HU-17). Promedios ponderados por distancia.
class HistoricoPuntaje {
  const HistoricoPuntaje({
    required this.desde,
    required this.hasta,
    required this.viajes,
    required this.viajesTotales,
    this.promedioTotal,
    this.promedio,
    this.calificacion,
    this.tendencia,
    this.puntos = const [],
    this.categorias,
    this.mejor,
    this.peor,
  });

  factory HistoricoPuntaje.fromJson(Map<String, dynamic> json) =>
      HistoricoPuntaje(
        desde: DateTime.parse(json['desde'] as String).toLocal(),
        hasta: DateTime.parse(json['hasta'] as String).toLocal(),
        viajes: json['viajes'] as int,
        viajesTotales: json['viajes_totales'] as int,
        promedioTotal: json['promedio_total'] as int?,
        promedio: json['promedio'] as int?,
        calificacion: switch (json['calificacion']) {
          final String codigo => Calificacion.desdeCodigo(codigo),
          _ => null,
        },
        tendencia: json['tendencia'] as int?,
        puntos: [
          for (final punto in json['puntos'] as List)
            PuntoHistorico.fromJson(punto as Map<String, dynamic>),
        ],
        categorias: switch (json['categorias']) {
          final Map<String, dynamic> categorias => {
            for (final MapEntry(:key, :value) in categorias.entries)
              CategoriaPuntaje.values.byName(key): PromedioCategoria.fromJson(
                value as Map<String, dynamic>,
              ),
          },
          _ => null,
        },
        mejor: switch (json['mejor']) {
          final Map<String, dynamic> viaje => ViajeDestacado.fromJson(viaje),
          _ => null,
        },
        peor: switch (json['peor']) {
          final Map<String, dynamic> viaje => ViajeDestacado.fromJson(viaje),
          _ => null,
        },
      );

  /// El periodo: de `desde` a la hora del servidor al responder.
  final DateTime desde;
  final DateTime hasta;

  /// Viajes del periodo.
  final int viajes;

  /// Todos los viajes con puntaje del conductor y su promedio, de cualquier
  /// fecha: Inicio los usa con menos de 3 viajes.
  final int viajesTotales;
  final int? promedioTotal;

  /// Del periodo; nulos si no tiene viajes.
  final int? promedio;
  final Calificacion? calificacion;

  /// Frente al periodo anterior de igual duración; nula si ese no tiene viajes.
  final int? tendencia;

  /// En orden cronológico: por viaje (7 días), por día (30) o por semana (3 meses).
  final List<PuntoHistorico> puntos;
  final Map<CategoriaPuntaje, PromedioCategoria>? categorias;
  final ViajeDestacado? mejor;

  /// Nulo con menos de 2 viajes.
  final ViajeDestacado? peor;

  /// Viajes con puntaje para que Inicio muestre la evolución.
  static const viajesParaEvolucion = 3;
}
