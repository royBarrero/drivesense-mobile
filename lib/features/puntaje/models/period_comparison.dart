import '../../recorridos/models/trip_history.dart';
import '../../recorridos/models/trip_score.dart';

/// Periodos calendario del comparativo (HU-20): el actual cuenta lo que va y
/// el anterior, completo.
enum PeriodoComparativo {
  semana('Semana', 'Esta semana', 'Semana pasada', PeriodoHistorial.semana),
  mes('Mes', 'Este mes', 'Mes pasado', PeriodoHistorial.mes);

  const PeriodoComparativo(
    this.texto,
    this.actual,
    this.anterior,
    this._historial,
  );

  /// En los chips.
  final String texto;
  final String actual;
  final String anterior;
  final PeriodoHistorial _historial;

  /// Medianoche local del lunes o del día 1, igual que el historial (HU-06).
  DateTime desde(DateTime ahora) => _historial.desde(ahora)!;
}

/// Cómo cambió un dato frente al periodo anterior.
enum ResultadoCambio {
  mejoro,
  empeoro,
  igual;

  static ResultadoCambio desdeCodigo(String codigo) => switch (codigo) {
    'mejoro' => mejoro,
    'empeoro' => empeoro,
    _ => igual,
  };
}

/// Diferencia (actual − anterior) y si es mejora; el backend decide el sentido
/// (el puntaje mejora al subir, los eventos por 10 km al bajar).
class CambioPuntaje {
  const CambioPuntaje({required this.diferencia, required this.resultado});

  factory CambioPuntaje.fromJson(Map<String, dynamic> json) => CambioPuntaje(
    diferencia: (json['diferencia'] as num).toDouble(),
    resultado: ResultadoCambio.desdeCodigo(json['resultado'] as String),
  );

  final double diferencia;
  final ResultadoCambio resultado;

  static CambioPuntaje? leer(Object? json) => switch (json) {
    final Map<String, dynamic> cambio => CambioPuntaje.fromJson(cambio),
    _ => null,
  };
}

/// Cifras de uno de los dos periodos.
class ResumenPeriodoComparativo {
  const ResumenPeriodoComparativo({
    required this.desde,
    required this.hasta,
    required this.viajes,
    required this.distanciaM,
    required this.eventos,
    this.drivescore,
    this.calificacion,
    this.categorias,
    this.eventosPor10Km,
  });

  factory ResumenPeriodoComparativo.fromJson(Map<String, dynamic> json) =>
      ResumenPeriodoComparativo(
        desde: DateTime.parse(json['desde'] as String).toLocal(),
        hasta: DateTime.parse(json['hasta'] as String).toLocal(),
        viajes: json['viajes'] as int,
        distanciaM: (json['distancia_m'] as num).toDouble(),
        eventos: json['eventos'] as int,
        drivescore: json['drivescore'] as int?,
        calificacion: switch (json['calificacion']) {
          final String codigo => Calificacion.desdeCodigo(codigo),
          _ => null,
        },
        categorias: switch (json['categorias']) {
          final Map<String, dynamic> categorias => {
            for (final MapEntry(:key, :value) in categorias.entries)
              CategoriaPuntaje.values.byName(key): value as int,
          },
          _ => null,
        },
        eventosPor10Km: (json['eventos_por_10km'] as num?)?.toDouble(),
      );

  final DateTime desde;
  final DateTime hasta;
  final int viajes;
  final double distanciaM;
  final int eventos;

  /// Nulos si el periodo no tiene viajes.
  final int? drivescore;
  final Calificacion? calificacion;
  final Map<CategoriaPuntaje, int>? categorias;
  final double? eventosPor10Km;
}

/// `GET /puntaje/comparativo` (HU-20). Promedios ponderados por distancia.
class ComparativoPuntaje {
  const ComparativoPuntaje({
    required this.periodo,
    required this.minimoViajes,
    required this.actual,
    required this.anterior,
    required this.comparable,
    this.drivescore,
    this.categorias,
    this.eventosPor10Km,
    this.viajes,
    this.distanciaM,
    this.masMejoro,
    this.masEmpeoro,
  });

  factory ComparativoPuntaje.fromJson(Map<String, dynamic> json) =>
      ComparativoPuntaje(
        periodo: PeriodoComparativo.values.byName(json['periodo'] as String),
        minimoViajes: json['minimo_viajes'] as int,
        actual: ResumenPeriodoComparativo.fromJson(
          json['actual'] as Map<String, dynamic>,
        ),
        anterior: ResumenPeriodoComparativo.fromJson(
          json['anterior'] as Map<String, dynamic>,
        ),
        comparable: json['comparable'] as bool,
        drivescore: CambioPuntaje.leer(json['drivescore']),
        categorias: switch (json['categorias']) {
          final Map<String, dynamic> categorias => {
            for (final MapEntry(:key, :value) in categorias.entries)
              CategoriaPuntaje.values.byName(key): CambioPuntaje.fromJson(
                value as Map<String, dynamic>,
              ),
          },
          _ => null,
        },
        eventosPor10Km: CambioPuntaje.leer(json['eventos_por_10km']),
        viajes: json['viajes'] as int?,
        distanciaM: (json['distancia_m'] as num?)?.toDouble(),
        masMejoro: _categoria(json['mas_mejoro']),
        masEmpeoro: _categoria(json['mas_empeoro']),
      );

  static CategoriaPuntaje? _categoria(Object? codigo) => switch (codigo) {
    final String nombre => CategoriaPuntaje.values.byName(nombre),
    _ => null,
  };

  final PeriodoComparativo periodo;

  /// Viajes con puntaje que necesita cada periodo para compararlos.
  final int minimoViajes;
  final ResumenPeriodoComparativo actual;
  final ResumenPeriodoComparativo anterior;

  /// Si es falso, lo que sigue es nulo: no hay datos para comparar.
  final bool comparable;
  final CambioPuntaje? drivescore;
  final Map<CategoriaPuntaje, CambioPuntaje>? categorias;
  final CambioPuntaje? eventosPor10Km;

  /// Diferencias sin sentido de mejora (más viajes no es manejar mejor).
  final int? viajes;
  final double? distanciaM;

  /// La categoría que más subió y la que más bajó; nulas si ninguna.
  final CategoriaPuntaje? masMejoro;
  final CategoriaPuntaje? masEmpeoro;
}
