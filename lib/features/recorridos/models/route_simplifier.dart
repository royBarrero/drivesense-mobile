import 'dart:math' as math;

import '../../telemetria/models/route.dart';

/// Umbrales del mapa del viaje (HU-29).
abstract final class UmbralesMapa {
  /// Desvío máximo de la ruta simplificada respecto de la original. Por debajo
  /// del error del GPS (se aceptan lecturas de hasta 20 m de precisión).
  static const toleranciaSimplificacionM = 5.0;
}

/// Ruta con menos puntos para dibujarla (Douglas-Peucker): ningún punto
/// descartado queda a más de [toleranciaM] metros de la ruta resultante.
/// Conserva el primero y el último.
///
/// Iterativo (con una pila propia): una ruta de 10 000 puntos no agota la
/// pila de llamadas.
List<PuntoRuta> simplificarRuta(
  List<PuntoRuta> puntos, {
  double toleranciaM = UmbralesMapa.toleranciaSimplificacionM,
}) {
  if (puntos.length < 3) return List.of(puntos);

  // Proyección local en metros (equirectangular): sobra para un viaje
  const radioTierraM = 6371000.0;
  final latitudBase = puntos.first.latitud * math.pi / 180;
  final escalaX = math.cos(latitudBase) * radioTierraM * math.pi / 180;
  const escalaY = radioTierraM * math.pi / 180;
  final xs = [for (final p in puntos) p.longitud * escalaX];
  final ys = [for (final p in puntos) p.latitud * escalaY];

  final conservar = List.filled(puntos.length, false);
  conservar[0] = true;
  conservar[puntos.length - 1] = true;

  final pendientes = <(int, int)>[(0, puntos.length - 1)];
  while (pendientes.isNotEmpty) {
    final (desde, hasta) = pendientes.removeLast();
    var mayor = 0.0;
    var indice = -1;
    for (var i = desde + 1; i < hasta; i++) {
      final distancia = _distanciaASegmento(
        xs[i],
        ys[i],
        xs[desde],
        ys[desde],
        xs[hasta],
        ys[hasta],
      );
      if (distancia > mayor) {
        mayor = distancia;
        indice = i;
      }
    }
    if (indice != -1 && mayor > toleranciaM) {
      conservar[indice] = true;
      pendientes
        ..add((desde, indice))
        ..add((indice, hasta));
    }
  }

  return [
    for (var i = 0; i < puntos.length; i++)
      if (conservar[i]) puntos[i],
  ];
}

/// Distancia del punto (px, py) al segmento (ax, ay)–(bx, by).
double _distanciaASegmento(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final largo2 = dx * dx + dy * dy;
  // Extremos iguales (p. ej. el conductor volvió al mismo lugar)
  final t = largo2 == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / largo2).clamp(0.0, 1.0);
  final cx = ax + t * dx - px;
  final cy = ay + t * dy - py;
  return math.sqrt(cx * cx + cy * cy);
}
