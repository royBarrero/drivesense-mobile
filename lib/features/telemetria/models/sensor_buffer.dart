import 'sensor_sample.dart';

/// Últimas lecturas de un sensor en memoria (búfer circular de tamaño fijo).
///
/// Lo consumen el filtro de señal (HU-09) y los detectores de eventos (HU-10 a 13).
class BuferCircular {
  BuferCircular({this.capacidad = capacidadPorDefecto})
    : assert(capacidad > 0),
      _muestras = List<MuestraSensor?>.filled(capacidad, null);

  /// ~10 s a 50 Hz.
  static const capacidadPorDefecto = 500;

  final int capacidad;
  final List<MuestraSensor?> _muestras;

  /// Posición donde se escribirá la próxima muestra.
  int _siguiente = 0;
  int _cantidad = 0;

  int get cantidad => _cantidad;
  bool get vacio => _cantidad == 0;

  /// La más reciente, o `null` si está vacío.
  MuestraSensor? get ultima =>
      vacio ? null : _muestras[(_siguiente - 1 + capacidad) % capacidad];

  /// Agrega una muestra; si está lleno, reemplaza la más antigua.
  void agregar(MuestraSensor muestra) {
    _muestras[_siguiente] = muestra;
    _siguiente = (_siguiente + 1) % capacidad;
    if (_cantidad < capacidad) _cantidad++;
  }

  /// Todas las muestras, de la más antigua a la más reciente.
  List<MuestraSensor> get muestras {
    final inicio = (_siguiente - _cantidad + capacidad) % capacidad;
    return [
      for (var i = 0; i < _cantidad; i++) _muestras[(inicio + i) % capacidad]!,
    ];
  }

  /// Muestras de los últimos [duracion] hasta [hasta] (por defecto, la más
  /// reciente), en orden cronológico.
  List<MuestraSensor> ventana(Duration duracion, {DateTime? hasta}) {
    final fin = hasta ?? ultima?.fecha;
    if (fin == null) return const [];
    final desde = fin.subtract(duracion);
    return [
      for (final muestra in muestras)
        if (muestra.fecha.isAfter(desde) && !muestra.fecha.isAfter(fin))
          muestra,
    ];
  }

  void vaciar() {
    _muestras.fillRange(0, capacidad, null);
    _siguiente = 0;
    _cantidad = 0;
  }
}
