import 'dart:collection';
import 'dart:math' as math;

import '../../recorridos/models/trip_accumulator.dart';
import 'sensor_sample.dart';

/// Valores de ajuste del filtro (HU-09), juntos para calibrarlos sin tocar la
/// lógica. Los iniciales salen de dos viajes reales del A34 (CLAUDE.md, HU-09).
abstract final class UmbralesFiltro {
  /// La gravedad (dirección vertical) es la media del acelerómetro en esta
  /// ventana: larga, para que una frenada sostenida no la incline.
  static const ventanaGravedad = Duration(seconds: 30);

  /// Datos mínimos para dar la vertical por buena.
  static const gravedadMinima = Duration(seconds: 3);

  /// Media corta del acelerómetro que se compara con la gravedad.
  static const ventanaOrientacion = Duration(seconds: 1);

  /// Si la orientación corta se aparta tanto de la gravedad durante
  /// [duracionCambioPosicion], el teléfono cambió de posición: se descarta el
  /// tramo y la gravedad vuelve a empezar. Una frenada o curva fuerte
  /// (~0,5 g) inclina ~27°.
  static const anguloCambioPosicionGrados = 35.0;
  static const duracionCambioPosicion = Duration(seconds: 2);

  /// Rotación fuera de la vertical (media de [ventanaRotacion]) a partir de la
  /// cual el teléfono se está moviendo solo. Manejando no pasó de 0,7 rad/s.
  static const rotacionTelefonoRadS = 1.0;
  static const ventanaRotacion = Duration(milliseconds: 200);

  /// Golpe vertical (media de [ventanaGolpe]) que se toma como bache fuerte.
  /// La media corta quita la vibración del motor.
  static const golpeVerticalMs2 = 5.0;
  static const ventanaGolpe = Duration(milliseconds: 100);

  /// Tramo descartado alrededor de un bache.
  static const margenBache = Duration(seconds: 1);

  /// Tramo descartado antes y después de que el teléfono se mueva.
  static const margenAntesMovimiento = Duration(seconds: 1);
  static const margenDespuesMovimiento = Duration(seconds: 2);

  /// Media del giro: suaviza la vibración (los umbrales de HU-12 usan 1 s).
  static const ventanaGiro = Duration(seconds: 1);

  /// Por debajo, el giro es el sesgo del giroscopio y se entrega como 0.
  static const zonaMuertaGiroRadS = 0.03;

  /// Lecturas del GPS con peor precisión se descartan.
  static const precisionMaximaM = UmbralesRecorrido.precisionMaximaM;

  /// Una sola lectura que baja (o sube) al menos esto respecto a la anterior
  /// y a la siguiente es un error del GPS (p. ej. un instante en 0 km/h).
  static const saltoAisladoMs = 1.5;

  /// Solo se compara con lecturas vecinas así de cercanas; tras un hueco no
  /// se sabe si el cambio fue aislado.
  static const separacionVecinasGps = Duration(seconds: 3);

  /// Velocidades y tramos descartados que se conservan.
  static const historialVelocidades = Duration(seconds: 30);
  static const historialDescartes = Duration(seconds: 60);
}

/// Velocidad del GPS ya confirmada por el filtro, con la posición de su
/// lectura.
class VelocidadFiltrada {
  const VelocidadFiltrada({
    required this.fecha,
    required this.velocidadMs,
    required this.latitud,
    required this.longitud,
  });

  final DateTime fecha;
  final double velocidadMs;
  final double latitud;
  final double longitud;

  double get velocidadKmh => velocidadMs * 3.6;
}

enum MotivoDescarte {
  bache('bache'),
  telefonoMovido('teléfono movido'),
  sinGravedad('calculando vertical');

  const MotivoDescarte(this.texto);

  /// Para el panel de diagnóstico.
  final String texto;
}

/// Filtro de señal (HU-09): entrega a los detectores (HU-10 a 13) una
/// velocidad confiable, el giro alrededor de la vertical y los tramos que no
/// deben evaluarse (bache fuerte o teléfono movido). No detecta eventos.
///
/// Recibe las muestras ya normalizadas a ~50 Hz por `LimitadorFrecuencia`.
class FiltroSenal {
  final _gravedad = _MediaPorSegundos(UmbralesFiltro.ventanaGravedad);
  final _orientacion = _MediaMovil(UmbralesFiltro.ventanaOrientacion);
  final _golpe = _MediaMovil(UmbralesFiltro.ventanaGolpe);
  final _rotacion = _MediaMovil(UmbralesFiltro.ventanaRotacion);
  final _giro = _MediaMovil(UmbralesFiltro.ventanaGiro);

  final _velocidades = Queue<VelocidadFiltrada>();
  final _descartes = Queue<_Tramo>();

  bool _sinGiroscopio = false;
  bool _conAcelerometro = false;

  /// Desde cuándo la orientación se aparta de la gravedad.
  DateTime? _desviadoDesde;

  /// Instante de la muestra de sensor más reciente.
  DateTime? _ultimaFecha;

  /// Última velocidad confirmada y la que espera a la siguiente lectura para
  /// saber si fue un salto aislado.
  Lectura? _anterior;
  Lectura? _pendiente;

  /// Velocidades confirmadas de los últimos 30 s, de la más antigua a la más
  /// reciente. Llegan con una lectura de retraso.
  List<VelocidadFiltrada> get velocidades => List.unmodifiable(_velocidades);

  /// La velocidad confirmada más reciente, sin copiar la lista (los giros la
  /// consultan con cada muestra del giroscopio).
  VelocidadFiltrada? get ultimaVelocidad =>
      _velocidades.isEmpty ? null : _velocidades.last;

  /// Giro alrededor de la vertical en rad/s (media de 1 s; 0 bajo la zona
  /// muerta). `null` sin giroscopio o mientras no hay vertical.
  double? get giroRadS {
    if (_sinGiroscopio || !_gravedad.lista || _giro.vacia) return null;
    final giro = _giro.media.x;
    return giro.abs() < UmbralesFiltro.zonaMuertaGiroRadS ? 0 : giro;
  }

  /// Por qué no se está evaluando ahora, o `null` si la señal es confiable.
  MotivoDescarte? get descarte {
    final ahora = _ultimaFecha;
    if (ahora == null) return null;
    for (final tramo in _descartes) {
      if (!ahora.isBefore(tramo.desde) && !ahora.isAfter(tramo.hasta)) {
        return tramo.motivo;
      }
    }
    if (_conAcelerometro && !_gravedad.lista) return MotivoDescarte.sinGravedad;
    return null;
  }

  /// `false` si el intervalo toca un tramo descartado (bache o teléfono
  /// movido): los detectores no deben evaluarlo.
  bool confiable(DateTime desde, DateTime hasta) => !_descartes.any(
    (tramo) => !hasta.isBefore(tramo.desde) && !desde.isAfter(tramo.hasta),
  );

  /// El teléfono no tiene giroscopio: solo velocidad, sin giro.
  void sinGiroscopio() => _sinGiroscopio = true;

  void acelerometro(MuestraSensor m) {
    _conAcelerometro = true;
    _registrarFecha(m.fecha);
    final a = _Vector(m.x, m.y, m.z);
    _gravedad.agregar(m.fecha, a);
    _orientacion.agregar(m.fecha, a);
    if (!_gravedad.lista) return;

    final g = _gravedad.media;
    final modulo = g.norma;
    final vertical = g / modulo;

    // Golpe vertical: aceleración sobre la vertical sin la gravedad
    _golpe.agregar(m.fecha, _Vector(a.punto(vertical) - modulo, 0, 0));
    if (_golpe.media.x.abs() >= UmbralesFiltro.golpeVerticalMs2) {
      _descartar(
        m.fecha.subtract(UmbralesFiltro.margenBache),
        m.fecha.add(UmbralesFiltro.margenBache),
        MotivoDescarte.bache,
      );
    }

    // Cambio de posición del teléfono: la orientación corta se aparta de la
    // gravedad más de lo que inclina cualquier maniobra
    final corta = _orientacion.media;
    final coseno = corta.punto(g) / (corta.norma * modulo);
    final grados = math.acos(coseno.clamp(-1.0, 1.0)) * 180 / math.pi;
    if (grados < UmbralesFiltro.anguloCambioPosicionGrados) {
      _desviadoDesde = null;
      return;
    }
    final desde = _desviadoDesde ??= m.fecha;
    _descartar(
      desde.subtract(UmbralesFiltro.margenAntesMovimiento),
      m.fecha.add(UmbralesFiltro.margenDespuesMovimiento),
      MotivoDescarte.telefonoMovido,
    );
    if (m.fecha.difference(desde) >= UmbralesFiltro.duracionCambioPosicion) {
      // Nueva posición: la vertical vuelve a empezar desde la orientación actual
      _gravedad.reiniciarCon(m.fecha, corta);
      _giro.vaciar();
      _desviadoDesde = null;
    }
  }

  void giroscopio(MuestraSensor m) {
    _registrarFecha(m.fecha);
    if (!_gravedad.lista) return;
    final w = _Vector(m.x, m.y, m.z);
    final vertical = _gravedad.media.unitario;
    final giro = w.punto(vertical);
    _giro.agregar(m.fecha, _Vector(giro, 0, 0));

    // Rotación fuera de la vertical: el auto casi no cabecea ni se ladea rápido
    final inclinacion = (w - vertical * giro).norma;
    _rotacion.agregar(m.fecha, _Vector(inclinacion, 0, 0));
    if (_rotacion.media.x >= UmbralesFiltro.rotacionTelefonoRadS) {
      _descartar(
        m.fecha.subtract(UmbralesFiltro.margenAntesMovimiento),
        m.fecha.add(UmbralesFiltro.margenDespuesMovimiento),
        MotivoDescarte.telefonoMovido,
      );
    }
  }

  void gps(Lectura lectura) {
    if (lectura.precisionM > UmbralesFiltro.precisionMaximaM ||
        lectura.velocidadMs < 0) {
      return;
    }
    final ultima = _pendiente ?? _anterior;
    if (ultima != null && !lectura.fecha.isAfter(ultima.fecha)) return;

    final anterior = _anterior;
    final pendiente = _pendiente;
    if (anterior == null) {
      // La primera no tiene con qué compararse
      _confirmar(lectura);
      return;
    }
    if (pendiente != null && !_saltoAislado(anterior, pendiente, lectura)) {
      _confirmar(pendiente);
    }
    _pendiente = lectura;
  }

  void reiniciar() {
    for (final media in [_orientacion, _golpe, _rotacion, _giro]) {
      media.vaciar();
    }
    _gravedad.vaciar();
    _velocidades.clear();
    _descartes.clear();
    _sinGiroscopio = false;
    _conAcelerometro = false;
    _desviadoDesde = null;
    _ultimaFecha = null;
    _anterior = null;
    _pendiente = null;
  }

  /// [lectura] baja o sube sola: las vecinas, cercanas, están ambas lejos de
  /// ella en el mismo sentido.
  bool _saltoAislado(Lectura anterior, Lectura lectura, Lectura siguiente) {
    const separacion = UmbralesFiltro.separacionVecinasGps;
    if (lectura.fecha.difference(anterior.fecha) > separacion ||
        siguiente.fecha.difference(lectura.fecha) > separacion) {
      return false;
    }
    const salto = UmbralesFiltro.saltoAisladoMs;
    final antes = lectura.velocidadMs - anterior.velocidadMs;
    final despues = siguiente.velocidadMs - lectura.velocidadMs;
    return (antes <= -salto && despues >= salto) ||
        (antes >= salto && despues <= -salto);
  }

  void _confirmar(Lectura lectura) {
    _anterior = lectura;
    _velocidades.add(
      VelocidadFiltrada(
        fecha: lectura.fecha,
        velocidadMs: lectura.velocidadMs,
        latitud: lectura.latitud,
        longitud: lectura.longitud,
      ),
    );
    final limite = lectura.fecha.subtract(UmbralesFiltro.historialVelocidades);
    while (_velocidades.first.fecha.isBefore(limite)) {
      _velocidades.removeFirst();
    }
  }

  void _registrarFecha(DateTime fecha) {
    final ultima = _ultimaFecha;
    if (ultima == null || fecha.isAfter(ultima)) _ultimaFecha = fecha;
  }

  /// Agrega un tramo descartado; si se superpone con el último del mismo
  /// motivo, lo alarga.
  void _descartar(DateTime desde, DateTime hasta, MotivoDescarte motivo) {
    final ultimo = _descartes.isEmpty ? null : _descartes.last;
    if (ultimo != null &&
        ultimo.motivo == motivo &&
        !desde.isAfter(ultimo.hasta)) {
      if (hasta.isAfter(ultimo.hasta)) ultimo.hasta = hasta;
    } else {
      _descartes.add(_Tramo(desde, hasta, motivo));
    }
    final limite = hasta.subtract(UmbralesFiltro.historialDescartes);
    while (_descartes.first.hasta.isBefore(limite)) {
      _descartes.removeFirst();
    }
  }
}

class _Tramo {
  _Tramo(this.desde, this.hasta, this.motivo);

  final DateTime desde;
  DateTime hasta;
  final MotivoDescarte motivo;
}

class _Vector {
  const _Vector(this.x, this.y, this.z);

  static const cero = _Vector(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double punto(_Vector o) => x * o.x + y * o.y + z * o.z;
  double get norma => math.sqrt(punto(this));
  _Vector get unitario => this / norma;

  _Vector operator +(_Vector o) => _Vector(x + o.x, y + o.y, z + o.z);
  _Vector operator -(_Vector o) => _Vector(x - o.x, y - o.y, z - o.z);
  _Vector operator *(double k) => _Vector(x * k, y * k, z * k);
  _Vector operator /(double k) => _Vector(x / k, y / k, z / k);
}

/// Media de las muestras de los últimos [ventana], con sumas acumuladas.
class _MediaMovil {
  _MediaMovil(this.ventana);

  final Duration ventana;
  final _muestras = Queue<(DateTime, _Vector)>();
  _Vector _suma = _Vector.cero;

  bool get vacia => _muestras.isEmpty;
  _Vector get media => _suma / _muestras.length.toDouble();

  void agregar(DateTime fecha, _Vector valor) {
    _muestras.add((fecha, valor));
    _suma = _suma + valor;
    final limite = fecha.subtract(ventana);
    while (!_muestras.first.$1.isAfter(limite)) {
      _suma = _suma - _muestras.removeFirst().$2;
    }
  }

  void vaciar() {
    _muestras.clear();
    _suma = _Vector.cero;
  }
}

/// Media de una ventana larga sin guardar cada muestra: sumas por segundo.
class _MediaPorSegundos {
  _MediaPorSegundos(this.ventana);

  final Duration ventana;
  final _casillas = Queue<_Casilla>();
  _Vector _suma = _Vector.cero;
  int _cantidad = 0;

  _Vector get media => _suma / _cantidad.toDouble();

  /// Hay al menos [UmbralesFiltro.gravedadMinima] de datos.
  bool get lista =>
      _casillas.isNotEmpty &&
      _casillas.last.segundo - _casillas.first.segundo + 1 >=
          UmbralesFiltro.gravedadMinima.inSeconds;

  void agregar(DateTime fecha, _Vector valor) {
    final segundo =
        fecha.microsecondsSinceEpoch ~/ Duration.microsecondsPerSecond;
    if (_casillas.isEmpty || _casillas.last.segundo != segundo) {
      _casillas.add(_Casilla(segundo));
    }
    _casillas.last
      ..suma = _casillas.last.suma + valor
      ..cantidad += 1;
    _suma = _suma + valor;
    _cantidad++;
    while (_casillas.first.segundo <= segundo - ventana.inSeconds) {
      final vieja = _casillas.removeFirst();
      _suma = _suma - vieja.suma;
      _cantidad -= vieja.cantidad;
    }
  }

  /// Empieza de nuevo con [media] como si llevara ya el mínimo necesario.
  void reiniciarCon(DateTime fecha, _Vector media) {
    vaciar();
    final segundo =
        fecha.microsecondsSinceEpoch ~/ Duration.microsecondsPerSecond;
    final segundos = UmbralesFiltro.gravedadMinima.inSeconds;
    for (var i = segundos - 1; i >= 0; i--) {
      final casilla = _Casilla(segundo - i)
        ..suma = media
        ..cantidad = 1;
      _casillas.add(casilla);
      _suma = _suma + media;
      _cantidad++;
    }
  }

  void vaciar() {
    _casillas.clear();
    _suma = _Vector.cero;
    _cantidad = 0;
  }
}

class _Casilla {
  _Casilla(this.segundo);

  final int segundo;
  _Vector suma = _Vector.cero;
  int cantidad = 0;
}
