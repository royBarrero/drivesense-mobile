/// Avance del conductor sobre la ruta planeada (HU-31). Dart puro.
library;

import 'dart:math' as math;

import '../../recorridos/models/trip_accumulator.dart';
import 'route_plan.dart';

/// Reglas del Copiloto por voz y del Modo aprendizaje (valores urbanos,
/// acordados; ver el CLAUDE.md).
abstract final class UmbralesCopiloto {
  /// Avisos de cada maniobra: lejos solo si el tramo es largo.
  static const avisoLejosM = 300.0;
  static const tramoLargoM = 400.0;
  static const avisoCercaM = 100.0;
  static const avisoAhoraM = 30.0;

  /// Distancia al destino para decir que llegó.
  static const llegadaM = 30.0;

  /// Desvío: más lejos de la ruta que esto durante [desvioDuracion], solo con
  /// lecturas de precisión [precisionMaximaM] o mejor.
  static const desvioM = 50.0;
  static const desvioDuracion = Duration(seconds: 5);
  static const precisionMaximaM = 20.0;

  /// Entre dos recálculos de la ruta.
  static const recalculoMinimo = Duration(seconds: 20);

  /// Modo aprendizaje: giro con velocidad alta.
  static const giroVelocidadKmh = 40.0;
  static const giroDistanciaM = 150.0;

  /// Modo aprendizaje: entre dos consejos y, en una maniobra puntual, cuánto
  /// después del evento se dice (para que la maniobra ya haya terminado).
  static const entreConsejos = Duration(seconds: 15);
  static const consejoTrasManiobra = Duration(seconds: 3);

  /// Un consejo no se dice si hubo una indicación de ruta hace menos que esto.
  static const silencioTrasIndicacion = Duration(seconds: 4);
}

/// Dónde está el conductor sobre la ruta.
class ProgresoRuta {
  const ProgresoRuta({
    required this.posicion,
    required this.distanciaARutaM,
    required this.recorridoM,
    required this.faltanM,
    required this.faltanS,
    required this.indicePaso,
    required this.proxima,
    required this.indiceProxima,
    required this.hastaProximaM,
    required this.segmento,
  });

  /// Punto de la ruta más cercano a la lectura.
  final Coordenada posicion;
  final double distanciaARutaM;
  final double recorridoM;
  final double faltanM;

  /// Tiempo restante: la duración de la ruta en proporción a lo que falta.
  final double faltanS;

  /// Paso en el que va (su maniobra ya pasó).
  final int indicePaso;

  /// Próxima maniobra (la llegada al final); nula si la ruta no tiene pasos.
  final PasoRuta? proxima;
  final int? indiceProxima;
  final double hastaProximaM;

  /// Segmento del trazado (de `segmento` a `segmento + 1`) donde se proyectó.
  final int segmento;

  bool get llego => faltanM <= UmbralesCopiloto.llegadaM;
}

/// Sigue al conductor sobre una ruta: proyecta cada lectura sobre el trazado.
///
/// Busca primero cerca del último segmento (y un poco por delante); si queda
/// lejos (curvas, desvío), busca en toda la ruta.
class SeguidorRuta {
  SeguidorRuta(this.ruta) : _acumulado = _acumular(ruta.trazado);

  final RutaPlaneada ruta;

  /// Distancia desde el inicio hasta cada punto del trazado.
  final List<double> _acumulado;
  int _segmento = 0;

  static const _atras = 2;
  static const _adelante = 40;

  /// Más lejos que esto en la búsqueda local: se busca en toda la ruta.
  static const _buscarTodaDesdeM = 30.0;

  static List<double> _acumular(List<Coordenada> trazado) {
    final acumulado = <double>[0];
    for (var i = 1; i < trazado.length; i++) {
      acumulado.add(acumulado.last + _distancia(trazado[i - 1], trazado[i]));
    }
    return acumulado;
  }

  static double _distancia(Coordenada a, Coordenada b) =>
      AcumuladorRecorrido.distanciaCoordenadas(
        a.latitud,
        a.longitud,
        b.latitud,
        b.longitud,
      );

  double get largoM => _acumulado.isEmpty ? 0 : _acumulado.last;

  /// Distancia desde el inicio de la ruta hasta el punto [indice] del trazado.
  double acumuladoEn(int indice) =>
      _acumulado[indice.clamp(0, _acumulado.length - 1)];

  ProgresoRuta actualizar(Coordenada lectura) {
    final trazado = ruta.trazado;
    if (trazado.length < 2) {
      final destino = trazado.isEmpty ? lectura : trazado.last;
      final falta = _distancia(lectura, destino);
      return ProgresoRuta(
        posicion: destino,
        distanciaARutaM: falta,
        recorridoM: 0,
        faltanM: falta,
        faltanS: 0,
        indicePaso: 0,
        proxima: ruta.pasos.isEmpty ? null : ruta.pasos.last,
        indiceProxima: ruta.pasos.isEmpty ? null : ruta.pasos.length - 1,
        hastaProximaM: falta,
        segmento: 0,
      );
    }

    var mejor = _buscar(
      lectura,
      math.max(0, _segmento - _atras),
      math.min(trazado.length - 2, _segmento + _adelante),
    );
    if (mejor.distancia > _buscarTodaDesdeM) {
      final todo = _buscar(lectura, 0, trazado.length - 2);
      if (todo.distancia < mejor.distancia) mejor = todo;
    }
    _segmento = mejor.segmento;

    final recorrido =
        _acumulado[mejor.segmento] +
        _distancia(trazado[mejor.segmento], mejor.punto);
    final faltan = math.max(0.0, largoM - recorrido);

    // Paso en curso: el último cuya maniobra (su inicio) ya quedó atrás
    final pasos = ruta.pasos;
    var indicePaso = 0;
    for (var i = 0; i < pasos.length; i++) {
      if (acumuladoEn(pasos[i].inicio) <= recorrido + 1) indicePaso = i;
    }
    final indiceProxima = indicePaso + 1 < pasos.length
        ? indicePaso + 1
        : (pasos.isEmpty ? null : pasos.length - 1);
    final proxima = indiceProxima == null ? null : pasos[indiceProxima];
    final hastaProxima = proxima == null
        ? faltan
        : math.max(0.0, acumuladoEn(proxima.inicio) - recorrido);

    return ProgresoRuta(
      posicion: mejor.punto,
      distanciaARutaM: mejor.distancia,
      recorridoM: recorrido,
      faltanM: faltan,
      faltanS: largoM == 0 ? 0 : ruta.duracionS * faltan / largoM,
      indicePaso: indicePaso,
      proxima: proxima,
      indiceProxima: indiceProxima,
      hastaProximaM: hastaProxima,
      segmento: mejor.segmento,
    );
  }

  /// Segmento más cercano a [lectura] entre [desde] y [hasta] (inclusive).
  ({int segmento, Coordenada punto, double distancia}) _buscar(
    Coordenada lectura,
    int desde,
    int hasta,
  ) {
    var mejorSegmento = desde;
    var mejorPunto = ruta.trazado[desde];
    var mejorDistancia = double.infinity;
    for (var i = desde; i <= hasta; i++) {
      final punto = _proyectar(lectura, ruta.trazado[i], ruta.trazado[i + 1]);
      final distancia = _distancia(lectura, punto);
      if (distancia < mejorDistancia) {
        mejorDistancia = distancia;
        mejorSegmento = i;
        mejorPunto = punto;
      }
    }
    return (
      segmento: mejorSegmento,
      punto: mejorPunto,
      distancia: mejorDistancia,
    );
  }

  /// Punto del segmento [a]–[b] más cercano a [p], en un plano local (las
  /// distancias de un segmento son cortas).
  static Coordenada _proyectar(Coordenada p, Coordenada a, Coordenada b) {
    final escalaLon = math.cos(p.latitud * math.pi / 180);
    final ax = a.longitud * escalaLon, ay = a.latitud;
    final bx = b.longitud * escalaLon, by = b.latitud;
    final px = p.longitud * escalaLon, py = p.latitud;
    final dx = bx - ax, dy = by - ay;
    final largo2 = dx * dx + dy * dy;
    if (largo2 == 0) return a;
    final t = (((px - ax) * dx + (py - ay) * dy) / largo2).clamp(0.0, 1.0);
    return Coordenada(
      a.latitud + (b.latitud - a.latitud) * t,
      a.longitud + (b.longitud - a.longitud) * t,
    );
  }
}

/// Decide si el conductor se salió de la ruta: más de
/// [UmbralesCopiloto.desvioM] durante [UmbralesCopiloto.desvioDuracion], solo
/// con lecturas precisas (las imprecisas no cuentan ni reinician).
class DetectorDesvio {
  DateTime? _lejosDesde;

  /// `true` mientras se considera desviado.
  bool evaluar({
    required double distanciaARutaM,
    required double precisionM,
    required DateTime ahora,
  }) {
    if (precisionM > UmbralesCopiloto.precisionMaximaM) {
      return _lejosDesde != null &&
          ahora.difference(_lejosDesde!) >= UmbralesCopiloto.desvioDuracion;
    }
    if (distanciaARutaM <= UmbralesCopiloto.desvioM) {
      _lejosDesde = null;
      return false;
    }
    _lejosDesde ??= ahora;
    return ahora.difference(_lejosDesde!) >= UmbralesCopiloto.desvioDuracion;
  }

  void reiniciar() => _lejosDesde = null;
}
