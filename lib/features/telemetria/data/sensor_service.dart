import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../recorridos/models/trip_accumulator.dart';
import '../models/event_detector.dart';
import '../models/rate_limiter.dart';
import '../models/sensor_buffer.dart';
import '../models/sensor_sample.dart';
import '../models/signal_filter.dart';

/// Acelerómetro (con gravedad) y giroscopio durante el viaje (HU-07).
///
/// Corre en el isolate principal: con la pantalla apagada sigue recibiendo
/// lecturas porque el servicio en primer plano de geolocator (con wakelock)
/// mantiene vivo el proceso.
class CapturaSensores {
  /// ~50 Hz.
  static const periodo = Duration(milliseconds: 20);

  /// Ventana con la que se mide la frecuencia real.
  static const _ventanaFrecuencia = Duration(seconds: 2);

  /// Muestras a ~50 Hz: las que consumen el filtro y los detectores.
  final acelerometro = BuferCircular();
  final giroscopio = BuferCircular();

  /// Velocidad y giro ya filtrados, para los detectores (HU-09).
  final filtro = FiltroSenal();

  /// Eventos de riesgo (HU-10 a HU-12), con la señal filtrada.
  final detector = DetectorEventos();

  /// Lo que entrega el sensor, antes de limitar la frecuencia (diagnóstico).
  final _crudoAcelerometro = BuferCircular();
  final _crudoGiroscopio = BuferCircular();
  final _limiteAcelerometro = LimitadorFrecuencia(periodo);
  final _limiteGiroscopio = LimitadorFrecuencia(periodo);

  StreamSubscription<AccelerometerEvent>? _acelerometro;
  StreamSubscription<GyroscopeEvent>? _giroscopio;
  bool _sinGiroscopio = false;

  /// Cuándo empezó la captura. Al conectarse, Android entrega primero la última
  /// lectura que tenía guardada, con su instante viejo (en el A34, la del final
  /// del viaje anterior): no es de este viaje y se descarta.
  DateTime _inicio = DateTime.now();

  /// Margen por la diferencia entre el reloj del sensor y el del teléfono.
  static const _margenInicio = Duration(seconds: 1);

  /// Recibe cada muestra tal como la entrega el sensor (modo calibración).
  void Function(TipoSensor tipo, MuestraSensor muestra)? oyente;

  /// Avisa si el teléfono no tiene giroscopio.
  void Function()? alFaltarGiroscopio;

  bool get capturando => _acelerometro != null;

  /// El teléfono no tiene giroscopio: el viaje sigue sin detección de giros.
  bool get sinGiroscopio => _sinGiroscopio;

  void iniciar() {
    detener();
    _inicio = DateTime.now();
    _acelerometro = accelerometerEventStream(samplingPeriod: periodo).listen(
      (e) => _agregar(TipoSensor.acelerometro, e.timestamp, e.x, e.y, e.z),
      // Sin acelerómetro no hay nada que registrar; el viaje sigue
      onError: (Object _) {},
    );
    _giroscopio = gyroscopeEventStream(samplingPeriod: periodo).listen(
      (e) => _agregar(TipoSensor.giroscopio, e.timestamp, e.x, e.y, e.z),
      onError: (Object error) {
        if (error is PlatformException && error.code == 'NO_SENSOR') {
          _sinGiroscopio = true;
          filtro.sinGiroscopio();
          alFaltarGiroscopio?.call();
        }
      },
    );
  }

  void detener() {
    _acelerometro?.cancel();
    _acelerometro = null;
    _giroscopio?.cancel();
    _giroscopio = null;
    for (final bufer in [
      acelerometro,
      giroscopio,
      _crudoAcelerometro,
      _crudoGiroscopio,
    ]) {
      bufer.vaciar();
    }
    _limiteAcelerometro.reiniciar();
    _limiteGiroscopio.reiniciar();
    filtro.reiniciar();
    detector
      ..reiniciar()
      ..alDetectar = null;
    oyente = null;
    alFaltarGiroscopio = null;
  }

  BuferCircular bufer(TipoSensor tipo) => switch (tipo) {
    TipoSensor.acelerometro => acelerometro,
    TipoSensor.giroscopio => giroscopio,
  };

  /// Muestras por segundo en los últimos 2 s (0 si dejaron de llegar); con
  /// [crudo], las que entrega el sensor antes de limitarlas.
  double frecuenciaHz(TipoSensor tipo, DateTime ahora, {bool crudo = false}) {
    final bufer = crudo
        ? switch (tipo) {
            TipoSensor.acelerometro => _crudoAcelerometro,
            TipoSensor.giroscopio => _crudoGiroscopio,
          }
        : this.bufer(tipo);
    final ultima = bufer.ultima?.fecha;
    // El instante del sensor sale de su propio reloj y puede ir algo adelantado
    final hasta = ultima != null && ultima.isAfter(ahora) ? ultima : ahora;
    return bufer.ventana(_ventanaFrecuencia, hasta: hasta).length /
        (_ventanaFrecuencia.inMilliseconds / 1000);
  }

  void _agregar(TipoSensor tipo, DateTime fecha, double x, double y, double z) {
    if (fecha.isBefore(_inicio.subtract(_margenInicio))) return;
    final muestra = MuestraSensor(fecha: fecha, x: x, y: y, z: z);
    oyente?.call(tipo, muestra);
    final (crudo, limite) = switch (tipo) {
      TipoSensor.acelerometro => (_crudoAcelerometro, _limiteAcelerometro),
      TipoSensor.giroscopio => (_crudoGiroscopio, _limiteGiroscopio),
    };
    crudo.agregar(muestra);
    if (!limite.aceptar(fecha)) return;
    bufer(tipo).agregar(muestra);
    switch (tipo) {
      case TipoSensor.acelerometro:
        filtro.acelerometro(muestra);
      case TipoSensor.giroscopio:
        filtro.giroscopio(muestra);
        detector.evaluarGiro(filtro, muestra.fecha);
    }
  }

  /// Lecturas del GPS para la velocidad filtrada y los detectores.
  void gps(Lectura lectura) {
    filtro.gps(lectura);
    detector.evaluar(filtro);
  }
}

final capturaSensoresProvider = Provider<CapturaSensores>((ref) {
  final captura = CapturaSensores();
  ref.onDispose(captura.detener);
  return captura;
});
