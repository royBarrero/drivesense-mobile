import 'dart:math' as math;

import '../../recorridos/models/trip_accumulator.dart';

/// Umbrales de la ruta (HU-08).
abstract final class UmbralesRuta {
  /// Se agrega un punto si pasó este tiempo desde el anterior...
  static const intervalo = Duration(seconds: 5);

  /// ...o si el conductor se alejó esta distancia (lo que ocurra primero).
  static const distanciaM = 20.0;

  /// Límite del backend (`MAXIMO_PUNTOS_RUTA`). Al llegar, la ruta se diezma.
  static const maximoPuntos = 10000;
}

/// Punto de la ruta: `PuntoRuta` del backend.
class PuntoRuta {
  const PuntoRuta({
    required this.latitud,
    required this.longitud,
    required this.fecha,
    required this.velocidadKmh,
  });

  factory PuntoRuta.desde(Lectura lectura) => PuntoRuta(
    latitud: lectura.latitud,
    longitud: lectura.longitud,
    fecha: lectura.fecha,
    // El backend no acepta velocidades mayores
    velocidadKmh: math.min(
      lectura.velocidadKmh,
      UmbralesRecorrido.velocidadMaximaApiKmh,
    ),
  );

  factory PuntoRuta.fromJson(Map<String, dynamic> json) => PuntoRuta(
    latitud: (json['lat'] as num).toDouble(),
    longitud: (json['lon'] as num).toDouble(),
    fecha: DateTime.parse(json['fecha'] as String),
    velocidadKmh: (json['velocidad_kmh'] as num).toDouble(),
  );

  final double latitud;
  final double longitud;
  final DateTime fecha;
  final double velocidadKmh;

  Map<String, dynamic> toJson() => {
    'lat': latitud,
    'lon': longitud,
    'fecha': fecha.toUtc().toIso8601String(),
    'velocidad_kmh': velocidadKmh,
  };
}

/// Arma la ruta del viaje con las lecturas que el acumulador ya aceptó
/// (mismos filtros de precisión y saltos que la distancia).
class ConstructorRuta {
  /// [puntos]: los ya guardados en el teléfono (al restaurar un viaje).
  ConstructorRuta([List<PuntoRuta> puntos = const []])
    : _puntos = [...puntos],
      _guardados = puntos.length;

  final List<PuntoRuta> _puntos;

  /// Cuántos de [_puntos] ya están en el archivo del teléfono.
  int _guardados;

  /// Tras diezmar hay que reescribir el archivo completo.
  bool _reescribir = false;

  List<PuntoRuta> get puntos => List.unmodifiable(_puntos);
  int get cantidad => _puntos.length;

  /// Agrega la lectura si pasaron [UmbralesRuta.intervalo] o
  /// [UmbralesRuta.distanciaM] desde el último punto; `true` si la agregó.
  bool agregar(Lectura lectura) {
    final ultimo = _puntos.isEmpty ? null : _puntos.last;
    if (ultimo != null) {
      final transcurrido = lectura.fecha.difference(ultimo.fecha);
      // El backend exige orden cronológico
      if (transcurrido.isNegative) return false;
      final distanciaM = AcumuladorRecorrido.distanciaCoordenadas(
        ultimo.latitud,
        ultimo.longitud,
        lectura.latitud,
        lectura.longitud,
      );
      if (transcurrido < UmbralesRuta.intervalo &&
          distanciaM < UmbralesRuta.distanciaM) {
        return false;
      }
    }
    _puntos.add(PuntoRuta.desde(lectura));
    if (_puntos.length > UmbralesRuta.maximoPuntos) _diezmar();
    return true;
  }

  /// Se queda con uno de cada dos puntos (conserva el primero y el último).
  void _diezmar() {
    final ultimo = _puntos.last;
    final conservados = [
      for (var i = 0; i < _puntos.length - 1; i += 2) _puntos[i],
      ultimo,
    ];
    _puntos
      ..clear()
      ..addAll(conservados);
    _reescribir = true;
  }

  /// Puntos a persistir desde el último guardado. Si [completa] es `true`
  /// reemplazan a todo lo guardado; si no, se agregan al final.
  ({bool completa, List<PuntoRuta> puntos}) tomarSinGuardar() {
    final completa = _reescribir;
    final nuevos = _puntos.sublist(completa ? 0 : _guardados);
    _guardados = _puntos.length;
    _reescribir = false;
    return (completa: completa, puntos: nuevos);
  }
}
