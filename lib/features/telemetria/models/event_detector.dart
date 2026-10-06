import 'signal_filter.dart';

/// Umbrales de los detectores de eventos (HU-10 a HU-13), acordados en el
/// CLAUDE.md: un estándar para conducción urbana, no lo que alcanza un auto en
/// particular.
abstract final class UmbralesDeteccion {
  /// Caída de la velocidad del GPS entre lecturas seguidas (~0,3 g).
  static const frenadaBruscaMs2 = 3.0;

  /// Subida de la velocidad del GPS entre lecturas seguidas (~0,25 g).
  static const aceleracionSeveraMs2 = 2.5;

  /// Aceleración lateral: velocidad del GPS × giro alrededor de la vertical
  /// (~0,35 g).
  static const giroAgresivoMs2 = 3.5;

  /// A esta velocidad o menos no se evalúan giros.
  static const velocidadMinimaGiroKmh = 15.0;

  /// Límite fijo para todos los viajes (por ahora no hay límites por vía).
  static const limiteVelocidadKmh = 60.0;

  /// Tiempo seguido sobre el límite para que cuente como exceso: un
  /// adelantamiento corto no lo dispara.
  static const duracionMinimaExceso = Duration(seconds: 5);

  /// El mismo tipo de evento no se repite antes de esto.
  static const separacionMinimaEventos = Duration(seconds: 3);

  /// Con un hueco mayor entre lecturas no se sabe cuándo cambió la velocidad:
  /// no se evalúa. En los giros, antigüedad máxima de la velocidad.
  static const separacionMaximaLecturas = UmbralesFiltro.separacionVecinasGps;
}

enum TipoEvento {
  frenadaBrusca('frenada_brusca'),
  aceleracionSevera('aceleracion_severa'),
  giroAgresivo('giro_agresivo'),
  excesoVelocidad('exceso_velocidad');

  const TipoEvento(this.codigo);

  /// Para el JSON.
  final String codigo;

  static TipoEvento desdeCodigo(String codigo) =>
      values.firstWhere((tipo) => tipo.codigo == codigo);
}

/// Maniobra de riesgo detectada durante el viaje.
class EventoRiesgo {
  const EventoRiesgo({
    required this.tipo,
    required this.fecha,
    required this.intensidad,
    required this.latitud,
    required this.longitud,
    required this.velocidadPreviaMs,
    this.velocidadMaximaMs,
    this.duracionS,
    this.enCurso = false,
  });

  factory EventoRiesgo.fromJson(Map<String, dynamic> json) => EventoRiesgo(
    tipo: TipoEvento.desdeCodigo(json['tipo'] as String),
    fecha: DateTime.parse(json['fecha'] as String),
    // `intensidad_ms2`: viajes en curso guardados antes de HU-13
    intensidad: ((json['intensidad'] ?? json['intensidad_ms2']) as num)
        .toDouble(),
    latitud: (json['latitud'] as num).toDouble(),
    longitud: (json['longitud'] as num).toDouble(),
    velocidadPreviaMs: (json['velocidad_previa_ms'] as num).toDouble(),
    velocidadMaximaMs: (json['velocidad_maxima_ms'] as num?)?.toDouble(),
    duracionS: (json['duracion_s'] as num?)?.toDouble(),
    enCurso: json['en_curso'] as bool? ?? false,
  );

  final TipoEvento tipo;

  /// Instante de la lectura del GPS con la que se detectó (en los giros, el
  /// de la muestra del giroscopio; en el exceso, el de la primera lectura
  /// sobre el límite). Junto con [tipo], identifica al evento mientras se
  /// actualiza.
  final DateTime fecha;

  /// Lo medido, siempre positivo. En m/s² en frenadas y aceleraciones (cambio
  /// de velocidad) y en giros (aceleración lateral, a cualquier lado); en el
  /// exceso de velocidad, los m/s de la máxima por encima del límite.
  final double intensidad;

  /// Posición de la lectura del GPS con la que se detectó (en el exceso, la
  /// de la primera lectura sobre el límite).
  final double latitud;
  final double longitud;

  /// Velocidad de la lectura anterior, antes de la maniobra; en los giros, la
  /// velocidad durante el giro, y en el exceso, la de la primera lectura sobre
  /// el límite.
  final double velocidadPreviaMs;

  /// Solo en el exceso: la velocidad máxima del tramo.
  final double? velocidadMaximaMs;

  /// Solo en el exceso: desde la primera hasta la última lectura sobre el
  /// límite, en segundos.
  final double? duracionS;

  /// El tramo sigue abierto: el evento todavía puede actualizarse (exceso).
  final bool enCurso;

  EventoRiesgo copyWith({
    double? intensidad,
    double? velocidadMaximaMs,
    double? duracionS,
    bool? enCurso,
  }) => EventoRiesgo(
    tipo: tipo,
    fecha: fecha,
    intensidad: intensidad ?? this.intensidad,
    latitud: latitud,
    longitud: longitud,
    velocidadPreviaMs: velocidadPreviaMs,
    velocidadMaximaMs: velocidadMaximaMs ?? this.velocidadMaximaMs,
    duracionS: duracionS ?? this.duracionS,
    enCurso: enCurso ?? this.enCurso,
  );

  /// Copia con el tramo cerrado, con lo acumulado hasta ahora.
  EventoRiesgo cerrado() => copyWith(enCurso: false);

  /// Como lo recibe el backend en el `PATCH .../finalizar` (HU-15): velocidades
  /// en km/h y, solo en el exceso, duración y velocidad máxima.
  factory EventoRiesgo.desdeApi(Map<String, dynamic> json) {
    final maximaKmh = (json['velocidad_maxima_kmh'] as num?)?.toDouble();
    return EventoRiesgo(
      tipo: TipoEvento.desdeCodigo(json['tipo'] as String),
      fecha: DateTime.parse(json['fecha'] as String),
      intensidad: (json['intensidad'] as num).toDouble(),
      latitud: (json['lat'] as num).toDouble(),
      longitud: (json['lon'] as num).toDouble(),
      velocidadPreviaMs: (json['velocidad_kmh'] as num).toDouble() / 3.6,
      velocidadMaximaMs: maximaKmh == null ? null : maximaKmh / 3.6,
      duracionS: (json['duracion_s'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toApiJson() {
    final maximaMs = velocidadMaximaMs;
    return {
      'tipo': tipo.codigo,
      'fecha': fecha.toUtc().toIso8601String(),
      'lat': latitud,
      'lon': longitud,
      'velocidad_kmh': velocidadPreviaMs * 3.6,
      'intensidad': intensidad,
      'duracion_s': ?duracionS,
      'velocidad_maxima_kmh': ?(maximaMs == null ? null : maximaMs * 3.6),
    };
  }

  Map<String, dynamic> toJson() => {
    'tipo': tipo.codigo,
    'fecha': fecha.toUtc().toIso8601String(),
    'intensidad': intensidad,
    'latitud': latitud,
    'longitud': longitud,
    'velocidad_previa_ms': velocidadPreviaMs,
    'velocidad_maxima_ms': ?velocidadMaximaMs,
    'duracion_s': ?duracionS,
    'en_curso': enCurso,
  };
}

/// Detecta frenadas bruscas (HU-10) y aceleraciones severas (HU-11) con el
/// cambio entre dos velocidades seguidas confirmadas por [FiltroSenal], giros
/// agresivos (HU-12) con la velocidad × el giro alrededor de la vertical
/// (estos tres, solo en intervalos confiables: sin bache ni teléfono movido) y
/// excesos de velocidad (HU-13) con la velocidad sostenida sobre el límite.
///
/// Un evento por maniobra: el mismo tipo no se repite hasta que su valor
/// vuelva bajo el umbral, y nunca antes de
/// [UmbralesDeteccion.separacionMinimaEventos]. Cada tipo lleva su propio
/// estado: una frenada no bloquea una aceleración.
class DetectorEventos {
  /// Tipos que salen del cambio de velocidad, con su signo (-1 si baja, 1 si
  /// sube) y su umbral.
  static const _porVelocidad = [
    (TipoEvento.frenadaBrusca, -1, UmbralesDeteccion.frenadaBruscaMs2),
    (TipoEvento.aceleracionSevera, 1, UmbralesDeteccion.aceleracionSeveraMs2),
  ];

  static const _limiteMs = UmbralesDeteccion.limiteVelocidadKmh / 3.6;

  /// Recibe cada evento nuevo o actualizado (el exceso de velocidad se avisa
  /// de nuevo mientras dura su tramo, con el mismo `tipo` y `fecha`).
  void Function(EventoRiesgo evento)? alDetectar;

  /// Instante de la última velocidad evaluada.
  DateTime? _evaluada;

  /// Tipos cuya última evaluación superó el umbral (la maniobra sigue).
  final _sobreUmbral = <TipoEvento>{};

  final _ultimoEvento = <TipoEvento, DateTime>{};

  /// Primera lectura del tramo sobre el límite, la máxima del tramo y su
  /// evento, una vez cumplida la duración mínima.
  VelocidadFiltrada? _excesoDesde;
  double _excesoMaximaMs = 0;
  EventoRiesgo? _exceso;

  /// Evalúa la velocidad confirmada más reciente, si no se evaluó ya. Se
  /// llama tras cada lectura del GPS.
  void evaluar(FiltroSenal filtro) {
    final actual = filtro.ultimaVelocidad;
    if (actual == null) return;
    final evaluada = _evaluada;
    if (evaluada != null && !actual.fecha.isAfter(evaluada)) return;
    _evaluada = actual.fecha;

    final velocidades = filtro.velocidades;
    final previa = velocidades.length < 2
        ? null
        : velocidades[velocidades.length - 2];
    final hueco =
        previa == null ||
        actual.fecha.difference(previa.fecha) >
            UmbralesDeteccion.separacionMaximaLecturas;
    _evaluarExceso(actual, tramoNuevo: hueco);

    // Con un hueco o un tramo descartado, la maniobra queda como estaba
    if (previa == null ||
        hueco ||
        !filtro.confiable(previa.fecha, actual.fecha)) {
      return;
    }

    final intervalo = actual.fecha.difference(previa.fecha);
    final segundos = intervalo.inMicroseconds / Duration.microsecondsPerSecond;
    final cambio = (actual.velocidadMs - previa.velocidadMs) / segundos;
    for (final (tipo, signo, umbral) in _porVelocidad) {
      _registrar(
        tipo,
        intensidad: cambio * signo,
        umbral: umbral,
        fecha: actual.fecha,
        lectura: actual,
        velocidadPreviaMs: previa.velocidadMs,
      );
    }
  }

  /// Evalúa el giro con la muestra del giroscopio tomada en [fecha]. Se llama
  /// tras cada muestra.
  void evaluarGiro(FiltroSenal filtro, DateTime fecha) {
    final giro = filtro.giroRadS;
    final velocidad = filtro.ultimaVelocidad;
    if (giro == null || velocidad == null) return;
    // Velocidad vieja (GPS sin señal) o tramo descartado: queda como estaba
    if (fecha.difference(velocidad.fecha) >
            UmbralesDeteccion.separacionMaximaLecturas ||
        !filtro.confiable(fecha.subtract(UmbralesFiltro.ventanaGiro), fecha)) {
      return;
    }
    final lento =
        velocidad.velocidadKmh <= UmbralesDeteccion.velocidadMinimaGiroKmh;
    _registrar(
      TipoEvento.giroAgresivo,
      intensidad: lento ? 0 : giro.abs() * velocidad.velocidadMs,
      umbral: UmbralesDeteccion.giroAgresivoMs2,
      fecha: fecha,
      lectura: velocidad,
      velocidadPreviaMs: velocidad.velocidadMs,
    );
  }

  void reiniciar() {
    _evaluada = null;
    _sobreUmbral.clear();
    _ultimoEvento.clear();
    // Sin avisar: el cierre al terminar o interrumpir el viaje lo hace
    // `ViajeActivo.cerrarEventosEnCurso`
    _excesoDesde = null;
    _exceso = null;
  }

  /// Exceso de velocidad: [actual] sobre el límite desde hace al menos
  /// [UmbralesDeteccion.duracionMinimaExceso], un evento por tramo. El evento
  /// se vuelve a avisar con cada lectura del tramo (máxima y duración) y,
  /// cerrado, al bajar al límite o tras un hueco ([tramoNuevo]), después del
  /// cual el tramo vuelve a empezar. No usa `confiable`: un bache o mover el
  /// teléfono no alteran la velocidad del GPS.
  void _evaluarExceso(VelocidadFiltrada actual, {required bool tramoNuevo}) {
    final sobre = actual.velocidadMs > _limiteMs;
    if (!sobre || tramoNuevo) _cerrarExceso();
    if (!sobre) return;

    final desde = _excesoDesde ??= actual;
    if (actual.velocidadMs > _excesoMaximaMs) {
      _excesoMaximaMs = actual.velocidadMs;
    }
    final duracion = actual.fecha.difference(desde.fecha);
    if (duracion < UmbralesDeteccion.duracionMinimaExceso) return;

    final segundos = duracion.inMicroseconds / Duration.microsecondsPerSecond;
    final evento =
        _exceso?.copyWith(
          intensidad: _excesoMaximaMs - _limiteMs,
          velocidadMaximaMs: _excesoMaximaMs,
          duracionS: segundos,
        ) ??
        EventoRiesgo(
          tipo: TipoEvento.excesoVelocidad,
          fecha: desde.fecha,
          intensidad: _excesoMaximaMs - _limiteMs,
          latitud: desde.latitud,
          longitud: desde.longitud,
          velocidadPreviaMs: desde.velocidadMs,
          velocidadMaximaMs: _excesoMaximaMs,
          duracionS: segundos,
          enCurso: true,
        );
    _exceso = evento;
    alDetectar?.call(evento);
  }

  /// Termina el tramo sobre el límite; si ya tenía evento, lo avisa cerrado.
  void _cerrarExceso() {
    final exceso = _exceso;
    _excesoDesde = null;
    _excesoMaximaMs = 0;
    _exceso = null;
    if (exceso != null) alDetectar?.call(exceso.cerrado());
  }

  /// Avisa un evento si [intensidad] cruza [umbral] (no si ya estaba sobre
  /// él) y pasó la separación mínima desde el anterior del mismo tipo.
  /// [lectura] da la posición.
  void _registrar(
    TipoEvento tipo, {
    required double intensidad,
    required double umbral,
    required DateTime fecha,
    required VelocidadFiltrada lectura,
    required double velocidadPreviaMs,
  }) {
    if (intensidad < umbral) {
      _sobreUmbral.remove(tipo);
      return;
    }
    if (!_sobreUmbral.add(tipo)) return;

    final ultimo = _ultimoEvento[tipo];
    if (ultimo != null &&
        fecha.difference(ultimo) < UmbralesDeteccion.separacionMinimaEventos) {
      return;
    }
    _ultimoEvento[tipo] = fecha;
    alDetectar?.call(
      EventoRiesgo(
        tipo: tipo,
        fecha: fecha,
        intensidad: intensidad,
        latitud: lectura.latitud,
        longitud: lectura.longitud,
        velocidadPreviaMs: velocidadPreviaMs,
      ),
    );
  }
}
