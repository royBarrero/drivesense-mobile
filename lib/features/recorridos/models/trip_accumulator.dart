import 'dart:math' as math;

/// Una posición del GPS, sin dependencias de geolocator (para poder probar el cálculo).
class Lectura {
  const Lectura({
    required this.latitud,
    required this.longitud,
    required this.precisionM,
    required this.velocidadMs,
    required this.fecha,
  });

  factory Lectura.fromJson(Map<String, dynamic> json) => Lectura(
    latitud: (json['latitud'] as num).toDouble(),
    longitud: (json['longitud'] as num).toDouble(),
    precisionM: (json['precision_m'] as num).toDouble(),
    velocidadMs: (json['velocidad_ms'] as num).toDouble(),
    fecha: DateTime.parse(json['fecha'] as String),
  );

  final double latitud;
  final double longitud;

  /// Radio de incertidumbre horizontal que informa el GPS.
  final double precisionM;

  /// Velocidad que informa el GPS (puede ser negativa si no la conoce).
  final double velocidadMs;
  final DateTime fecha;

  double get velocidadKmh => math.max(0, velocidadMs) * 3.6;

  Map<String, dynamic> toJson() => {
    'latitud': latitud,
    'longitud': longitud,
    'precision_m': precisionM,
    'velocidad_ms': velocidadMs,
    'fecha': fecha.toUtc().toIso8601String(),
  };
}

/// Umbrales del cálculo. Ajustables tras probar en el teléfono.
abstract final class UmbralesRecorrido {
  /// Lecturas con peor precisión se descartan.
  static const precisionMaximaM = 20.0;

  /// Un tramo más rápido que esto es un salto del GPS, no movimiento real.
  static const velocidadImposibleKmh = 200.0;

  /// Por debajo se considera que el teléfono está quieto (temblor del GPS).
  static const velocidadQuietoKmh = 1.0;

  /// Tras tantos saltos seguidos se toma la lectura nueva como referencia
  /// (la anterior era la errónea).
  static const saltosParaReubicar = 3;

  /// Sin lecturas durante este tiempo la velocidad actual se muestra como 0.
  static const lecturaVigente = Duration(seconds: 5);

  /// Límite del backend para las velocidades.
  static const velocidadMaximaApiKmh = 300.0;
}

/// Acumula distancia y velocidad máxima de un recorrido a partir de las lecturas del GPS.
///
/// La duración no se guarda: sale del reloj ([inicio] → ahora o fin).
class AcumuladorRecorrido {
  AcumuladorRecorrido({required this.inicio});

  factory AcumuladorRecorrido.fromJson(Map<String, dynamic> json) {
    final ultima = json['ultima_lectura'];
    return AcumuladorRecorrido(inicio: DateTime.parse(json['inicio'] as String))
      .._distanciaM = (json['distancia_m'] as num).toDouble()
      .._velocidadMaximaKmh = (json['velocidad_maxima_kmh'] as num).toDouble()
      .._ultimaLectura = ultima == null
          ? null
          : Lectura.fromJson(ultima as Map<String, dynamic>);
    // _referencia queda nula: al continuar no se une el hueco sin registrar
  }

  /// Hora de inicio según el reloj del teléfono.
  final DateTime inicio;

  double _distanciaM = 0;
  double _velocidadMaximaKmh = 0;

  /// Última lectura aceptada: da la velocidad actual y el punto de llegada.
  Lectura? _ultimaLectura;

  /// Punto desde el que se mide el siguiente tramo.
  Lectura? _referencia;
  int _saltosSeguidos = 0;

  double get distanciaM => _distanciaM;
  double get velocidadMaximaKmh => _velocidadMaximaKmh;
  Lectura? get ultimaLectura => _ultimaLectura;

  /// Procesa una lectura; devuelve `false` si se descartó.
  bool agregar(Lectura lectura) {
    if (lectura.precisionM > UmbralesRecorrido.precisionMaximaM) return false;

    final referencia = _referencia;
    if (referencia != null) {
      final segundos =
          lectura.fecha.difference(referencia.fecha).inMilliseconds / 1000;
      if (segundos <= 0) return false;

      final tramoM = distanciaEntre(referencia, lectura);
      if (tramoM / segundos * 3.6 > UmbralesRecorrido.velocidadImposibleKmh) {
        _saltosSeguidos++;
        if (_saltosSeguidos < UmbralesRecorrido.saltosParaReubicar) {
          return false;
        }
        // La referencia era la lectura errónea: se reubica sin sumar el tramo
        _saltosSeguidos = 0;
        _referencia = lectura;
        _aceptar(lectura);
        return true;
      }
      _saltosSeguidos = 0;

      final quieto =
          lectura.velocidadKmh < UmbralesRecorrido.velocidadQuietoKmh;
      if (quieto && tramoM < lectura.precisionM) {
        // Temblor del GPS con el teléfono quieto: no se suma ni se mueve la referencia
        _aceptar(lectura);
        return true;
      }
      _distanciaM += tramoM;
    }

    _referencia = lectura;
    _aceptar(lectura);
    return true;
  }

  void _aceptar(Lectura lectura) {
    _ultimaLectura = lectura;
    _velocidadMaximaKmh = math.max(
      _velocidadMaximaKmh,
      math.min(lectura.velocidadKmh, UmbralesRecorrido.velocidadMaximaApiKmh),
    );
  }

  /// Velocidad a mostrar: la de la última lectura si es reciente; si no, 0.
  double velocidadActualKmh(DateTime ahora) {
    final ultima = _ultimaLectura;
    if (ultima == null) return 0;
    if (ahora.difference(ultima.fecha) > UmbralesRecorrido.lecturaVigente) {
      return 0;
    }
    return ultima.velocidadKmh;
  }

  /// Segundos desde [inicio] hasta [fin] (nunca negativo).
  int duracionS(DateTime fin) => math.max(0, fin.difference(inicio).inSeconds);

  /// Distancia / duración, sin superar la máxima (el backend lo exige).
  double velocidadPromedioKmh(int duracionS) {
    if (duracionS <= 0) return 0;
    final promedio = _distanciaM / duracionS * 3.6;
    return math.min(promedio, _velocidadMaximaKmh);
  }

  Map<String, dynamic> toJson() => {
    'inicio': inicio.toUtc().toIso8601String(),
    'distancia_m': _distanciaM,
    'velocidad_maxima_kmh': _velocidadMaximaKmh,
    'ultima_lectura': _ultimaLectura?.toJson(),
  };

  /// Distancia en metros entre dos lecturas (fórmula de haversine).
  static double distanciaEntre(Lectura a, Lectura b) {
    const radioTierraM = 6371000.0;
    double rad(double grados) => grados * math.pi / 180;
    final dLat = rad(b.latitud - a.latitud);
    final dLon = rad(b.longitud - a.longitud);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitud)) *
            math.cos(rad(b.latitud)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * radioTierraM * math.asin(math.sqrt(h));
  }
}
