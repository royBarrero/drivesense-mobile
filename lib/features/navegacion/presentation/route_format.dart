import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../recorridos/presentation/trip_format.dart';
import '../models/route_plan.dart';

/// Textos e íconos de la ruta planeada (HU-30).
abstract final class FormatoRuta {
  /// `850 m` (a la decena) bajo 1 km; desde ahí, `3,12 km`.
  static String distancia(double metros) {
    if (metros < 995) return '${(metros / 10).round() * 10} m';
    return '${FormatoViaje.kilometros(metros)} km';
  }

  /// `7 min`, `1 h 05 min`; un tramo corto se muestra como `1 min`.
  static String duracion(double segundos) =>
      FormatoViaje.duracionCorta(math.max(60, (segundos / 60).round() * 60));

  /// `3,12 km · 7 min`.
  static String resumen(RutaPlaneada ruta) =>
      '${distancia(ruta.distanciaM)} · ${duracion(ruta.duracionS)}';

  /// Coordenadas de un punto del mapa: `-17.78340, -63.18210`.
  static String coordenadas(Coordenada punto) =>
      '${punto.latitud.toStringAsFixed(5)}, '
      '${punto.longitud.toStringAsFixed(5)}';

  static IconData icono(TipoPaso tipo) => switch (tipo) {
    TipoPaso.girarIzquierda => Icons.turn_left_rounded,
    TipoPaso.girarDerecha => Icons.turn_right_rounded,
    TipoPaso.girarFuerteIzquierda => Icons.turn_sharp_left_rounded,
    TipoPaso.girarFuerteDerecha => Icons.turn_sharp_right_rounded,
    TipoPaso.girarLeveIzquierda => Icons.turn_slight_left_rounded,
    TipoPaso.girarLeveDerecha => Icons.turn_slight_right_rounded,
    TipoPaso.seguirRecto => Icons.straight_rounded,
    TipoPaso.entrarRotonda ||
    TipoPaso.salirRotonda => Icons.roundabout_right_rounded,
    TipoPaso.mediaVuelta => Icons.u_turn_left_rounded,
    TipoPaso.llegada => Icons.flag_rounded,
    TipoPaso.salida => Icons.trip_origin_rounded,
    TipoPaso.mantenerIzquierda => Icons.fork_left_rounded,
    TipoPaso.mantenerDerecha => Icons.fork_right_rounded,
  };
}
