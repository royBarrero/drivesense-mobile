/// Deja pasar muestras a un ritmo fijo (HU-07).
///
/// Android toma el periodo pedido como una sugerencia: en el A34 el acelerómetro
/// entrega ~125 Hz aunque se pidan 50. Se acepta la primera muestra de cada
/// intervalo de una grilla de [periodo], así el promedio queda en la frecuencia
/// pedida aunque el sensor vaya más rápido.
class LimitadorFrecuencia {
  LimitadorFrecuencia(this.periodo);

  final Duration periodo;

  /// Margen para no descartar una muestra que llega apenas antes de su turno
  /// (el sensor no es exacto: a 50 Hz llegan cada 19-21 ms).
  static const _tolerancia = Duration(milliseconds: 5);

  DateTime? _siguiente;

  /// `true` si la muestra tomada en [fecha] debe conservarse.
  bool aceptar(DateTime fecha) {
    final siguiente = _siguiente;
    if (siguiente != null && fecha.isBefore(siguiente.subtract(_tolerancia))) {
      return false;
    }
    // Tras un hueco (o al empezar) la grilla arranca de nuevo en esta muestra
    _siguiente = siguiente == null || fecha.isAfter(siguiente.add(periodo))
        ? fecha.add(periodo)
        : siguiente.add(periodo);
    return true;
  }

  void reiniciar() => _siguiente = null;
}
