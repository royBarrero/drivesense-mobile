/// Una lectura de un sensor de movimiento (HU-07), sin dependencias de
/// sensors_plus (para poder probar el búfer y, más adelante, el filtro y los detectores).
class MuestraSensor {
  const MuestraSensor({
    required this.fecha,
    required this.x,
    required this.y,
    required this.z,
  });

  /// Instante en que el sensor tomó la lectura (no cuando llegó a la app).
  final DateTime fecha;

  /// Acelerómetro: m/s², con gravedad. Giroscopio: rad/s.
  final double x;
  final double y;
  final double z;
}

enum TipoSensor { acelerometro, giroscopio }
