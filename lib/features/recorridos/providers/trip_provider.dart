import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_error.dart';
import '../../auth/providers/session_provider.dart';
import '../../telemetria/data/calibration_recorder.dart';
import '../../telemetria/data/event_alert_service.dart';
import '../../telemetria/data/sensor_service.dart';
import '../../telemetria/models/event_detector.dart';
import '../../telemetria/models/live_alerts.dart';
import '../../telemetria/providers/alert_sound_provider.dart';
import '../../telemetria/providers/calibration_mode_provider.dart';
import '../data/location_service.dart';
import '../data/trip_local_storage.dart';
import '../data/trips_repository.dart';
import '../models/trip.dart';
import '../models/trip_accumulator.dart';
import '../models/trip_score.dart';
import 'pending_summary_provider.dart';

/// Error al iniciar, continuar o finalizar un viaje; la pantalla muestra [mensaje].
class ErrorRecorrido implements Exception {
  const ErrorRecorrido(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ErrorRecorrido: $mensaje';
}

sealed class EstadoViaje {
  const EstadoViaje();
}

class SinViaje extends EstadoViaje {
  const SinViaje();
}

/// Registrando. Se publica un estado nuevo cada segundo y con cada lectura del GPS.
class ViajeEnCurso extends EstadoViaje {
  const ViajeEnCurso({
    required this.viaje,
    required this.ahora,
    this.sinSenal = false,
    this.lecturaGps,
    this.avisoPuntual,
    this.avisoPuntualDesde,
  });

  final ViajeActivo viaje;
  final DateTime ahora;

  /// No llegan lecturas del GPS (apagado, sin cielo despejado...).
  final bool sinSenal;

  /// Última lectura del GPS, aunque el acumulador la haya descartado
  /// (panel de diagnóstico).
  final Lectura? lecturaGps;

  /// Último evento puntual y desde cuándo se avisa (HU-14).
  final EventoRiesgo? avisoPuntual;
  final DateTime? avisoPuntualDesde;

  /// Lo que muestra el encabezado ahora: el puntual vigente o el exceso
  /// abierto.
  AvisoEnVivo get aviso => AvisoEnVivo.de(
    eventos: viaje.eventos,
    ahora: ahora,
    puntual: avisoPuntual,
    puntualDesde: avisoPuntualDesde,
  );

  double get velocidadKmh => viaje.acumulador.velocidadActualKmh(ahora);
  int get duracionS => viaje.acumulador.duracionS(ahora);
  double get distanciaM => viaje.acumulador.distanciaM;
}

/// Hay un recorrido en curso pero la app se cerró: se ofrece continuar o finalizar.
class ViajeInterrumpido extends EstadoViaje {
  const ViajeInterrumpido(this.viaje);

  final ViajeActivo viaje;
}

enum ResultadoViaje { finalizado, descartado, pendiente, rechazado }

/// Viaje recién finalizado: datos de la pantalla de resumen.
class ViajeTerminado extends EstadoViaje {
  const ViajeTerminado(
    this.resumen,
    this.resultado, {
    this.mensaje,
    this.archivoCalibracion,
    this.puntaje,
  });

  final ResumenRecorrido resumen;
  final ResultadoViaje resultado;

  /// DriveScore (HU-15). Nulo mientras el envío está pendiente o si no se pudo
  /// obtener.
  final PuntajeViaje? puntaje;

  /// Motivo si el backend lo rechazó.
  final String? mensaje;

  /// CSV del modo calibración, para compartirlo (solo en desarrollo).
  final String? archivoCalibracion;
}

/// Recorrido del conductor (HU-04 y HU-05), con la captura de sensores (HU-07)
/// y la ruta (HU-08).
class ViajeNotifier extends AsyncNotifier<EstadoViaje> {
  static const _sinSenalTras = Duration(seconds: 10);
  static const _guardarCada = 5; // segundos

  StreamSubscription<Lectura>? _lecturas;
  StreamSubscription<bool>? _cambiosGps;
  Timer? _reloj;
  int _segundos = 0;
  DateTime _ultimaLecturaRecibida = DateTime.now();
  Lectura? _ultimaLecturaGps;

  /// Avisos en vivo del viaje (HU-14).
  final _avisos = GestorAvisos();

  /// Se guardan al empezar: en `onDispose` no se puede usar `ref`.
  CapturaSensores? _sensores;
  RegistroCalibracion? _calibracion;

  int? get _usuarioId => ref.read(sesionProvider).value?.id;
  AlmacenRecorrido get _almacen => ref.read(almacenRecorridoProvider);
  ServicioUbicacion get _ubicacion => ref.read(servicioUbicacionProvider);

  @override
  Future<EstadoViaje> build() async {
    final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
    ref.onDispose(_detenerSeguimiento);
    if (usuarioId == null) return const SinViaje();
    return _restaurar(usuarioId);
  }

  /// Al abrir la app: cruza lo guardado en el teléfono con `GET /recorridos/activo`.
  Future<EstadoViaje> _restaurar(int usuarioId) async {
    final almacen = _almacen;
    final local = await almacen.leerViaje(usuarioId);
    final pendiente = await almacen.leerResumen(usuarioId);
    try {
      final activo = await ref
          .read(recorridosRepositorioProvider)
          .obtenerActivo();
      // Ya finalizado en el teléfono y con el resumen aún sin llegar: el
      // backend lo sigue viendo en curso, pero el reenvío lo cerrará
      if (activo == null || activo.id == pendiente?.recorridoId) {
        // Ya se finalizó (o nunca existió en el backend)
        if (local != null) await almacen.borrarViaje(usuarioId);
        return const SinViaje();
      }
      if (local != null && local.recorridoId == activo.id) {
        return ViajeInterrumpido(local);
      }
      // En curso en el backend pero sin datos en el teléfono: acumulados en cero
      final viaje = ViajeActivo(
        recorridoId: activo.id,
        fechaInicioServidor: activo.fechaInicio,
        acumulador: AcumuladorRecorrido(inicio: activo.fechaInicio),
      );
      await almacen.guardarViaje(usuarioId, viaje);
      return ViajeInterrumpido(viaje);
    } on ErrorApi {
      // Sin conexión: se confía en lo guardado en el teléfono
      return local == null ? const SinViaje() : ViajeInterrumpido(local);
    }
  }

  /// Crea el recorrido en el backend y empieza a registrar.
  /// Los permisos y el GPS se preparan antes, desde la pantalla.
  Future<void> iniciar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null || state.value is! SinViaje) return;

    // Con un viaje anterior sin enviar, el backend respondería 409
    final pendientes = ref.read(resumenPendienteProvider.notifier);
    await pendientes.enviar();
    if (await _almacen.leerResumen(usuarioId) != null) {
      throw const ErrorRecorrido(
        'Tu viaje anterior aún no se ha enviado. Se enviará cuando haya '
        'conexión y luego podrás iniciar otro.',
      );
    }

    final partida = await _posicionActual();
    final Recorrido recorrido;
    try {
      recorrido = await ref
          .read(recorridosRepositorioProvider)
          .iniciar(latitud: partida.latitud, longitud: partida.longitud);
    } on ErrorApi catch (e) {
      // 409: hay uno en curso (p. ej. desde otro teléfono); se vuelve a
      // consultar para ofrecer continuarlo
      if (e.codigo == 409) ref.invalidateSelf();
      throw ErrorRecorrido(e.mensaje);
    }

    final viaje = ViajeActivo(
      recorridoId: recorrido.id,
      fechaInicioServidor: recorrido.fechaInicio,
      acumulador: AcumuladorRecorrido(inicio: DateTime.now()),
    );
    _procesar(viaje, partida);
    await _almacen.guardarViaje(usuarioId, viaje);
    _comenzarSeguimiento(viaje, nuevo: true);
  }

  /// Retoma un viaje interrumpido. El tramo sin registrar no suma distancia;
  /// el cronómetro sigue contando desde el inicio.
  void continuar() {
    final actual = state.value;
    if (actual is ViajeInterrumpido) {
      // Un exceso de velocidad que quedó abierto termina con lo acumulado; si
      // se sigue sobre el límite, empieza un tramo nuevo
      actual.viaje.cerrarEventosEnCurso();
      _guardar(actual.viaje);
      _comenzarSeguimiento(actual.viaje, nuevo: false);
    }
  }

  /// Envía el resumen y deja el estado en [ViajeTerminado].
  ///
  /// En curso: llega a la hora actual. Interrumpido: a la hora y el lugar del
  /// último punto registrado, para no alargar el viaje con el tiempo que la app
  /// estuvo cerrada.
  Future<void> finalizar() async {
    final usuarioId = _usuarioId;
    final actual = state.value;
    if (usuarioId == null) return;

    final ViajeActivo viaje;
    final bool interrumpido;
    switch (actual) {
      case ViajeEnCurso():
        viaje = actual.viaje;
        interrumpido = false;
      case ViajeInterrumpido():
        viaje = actual.viaje;
        interrumpido = true;
      default:
        return;
    }

    // Sin ninguna lectura precisa (o sin datos en el teléfono) se pide la posición
    final llegada = viaje.acumulador.ultimaLectura ?? await _posicionActual();
    final fechaFin = interrumpido ? llegada.fecha : DateTime.now();
    // Sin guardar: el viaje se borra del teléfono enseguida, y un guardado sin
    // esperar podría escribirse después y hacerlo reaparecer
    viaje.cerrarEventosEnCurso();
    _detenerSeguimiento();
    final archivoCalibracion = await _archivoCalibracion(viaje.recorridoId);

    final resumen = ResumenRecorrido.desde(
      viaje,
      fechaFin: fechaFin,
      llegada: llegada,
    );
    // Primero queda guardado como pendiente: si el envío falla, se reintenta solo
    final pendientes = ref.read(resumenPendienteProvider.notifier);
    await pendientes.guardar(resumen);
    await _almacen.borrarViaje(usuarioId);
    final envio = await pendientes.enviar();
    if (!ref.mounted) return;

    state = AsyncData(switch (envio?.resultado) {
      ResultadoEnvio.enviado => _terminado(
        resumen,
        envio!,
        archivoCalibracion: archivoCalibracion,
      ),
      ResultadoEnvio.rechazado => ViajeTerminado(
        resumen,
        ResultadoViaje.rechazado,
        mensaje: envio!.mensaje,
        archivoCalibracion: archivoCalibracion,
      ),
      ResultadoEnvio.pendiente || null => ViajeTerminado(
        resumen,
        ResultadoViaje.pendiente,
        archivoCalibracion: archivoCalibracion,
      ),
    });
  }

  /// El resumen pendiente llegó al backend (reintento): si la pantalla de
  /// resumen de ese viaje lo esperaba, muestra el resultado y el DriveScore.
  void alEnviarResumen(int recorridoId, Envio envio) {
    final actual = state.value;
    if (actual is! ViajeTerminado ||
        actual.resultado != ResultadoViaje.pendiente ||
        actual.resumen.recorridoId != recorridoId) {
      return;
    }
    state = AsyncData(
      _terminado(
        actual.resumen,
        envio,
        archivoCalibracion: actual.archivoCalibracion,
      ),
    );
  }

  ViajeTerminado _terminado(
    ResumenRecorrido resumen,
    Envio envio, {
    String? archivoCalibracion,
  }) => ViajeTerminado(
    resumen,
    envio.recorrido?.estado == EstadoRecorrido.descartado
        ? ResultadoViaje.descartado
        : ResultadoViaje.finalizado,
    archivoCalibracion: archivoCalibracion,
    puntaje: envio.puntaje,
  );

  /// Sale de la pantalla de resumen.
  void cerrarResumen() {
    if (state.value is ViajeTerminado) state = const AsyncData(SinViaje());
  }

  /// [nuevo]: recién iniciado (no un viaje interrumpido que se continúa).
  void _comenzarSeguimiento(ViajeActivo viaje, {required bool nuevo}) {
    _detenerSeguimiento();
    _segundos = 0;
    _ultimaLecturaRecibida = DateTime.now();
    _ultimaLecturaGps = null;

    // Acelerómetro y giroscopio (HU-07); sin giroscopio el viaje sigue
    final sensores = ref.read(capturaSensoresProvider)
      ..iniciar()
      ..alFaltarGiroscopio = () => viaje.sinGiroscopio = true;
    // Se guarda en cuanto se detecta o se actualiza (el exceso de velocidad,
    // con cada lectura mientras dura), sin esperar al guardado periódico, y
    // se avisa al instante (HU-14)
    _avisos.reiniciar();
    // Se carga ya: el primer evento debe respetar la preferencia
    ref.read(sonidoAvisosProvider);
    sensores.detector.alDetectar = (evento) {
      registrarYAvisar(
        viaje,
        evento,
        avisos: _avisos,
        servicio: ref.read(avisosEventoProvider),
        sonido: ref.read(sonidoAvisosProvider).value ?? true,
        ahora: DateTime.now(),
      );
      _guardar(viaje);
      _publicar(viaje);
    };
    _sensores = sensores;
    if (kDebugMode) _iniciarCalibracion(viaje, nuevo: nuevo);
    _publicar(viaje);

    _suscribirLecturas(viaje);
    // Si se apaga el GPS el flujo falla; al volver a encenderlo se reanuda
    _cambiosGps = _ubicacion.cambiosGps().listen((encendido) {
      if (encendido) _suscribirLecturas(viaje);
    });
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      _segundos++;
      if (_segundos % _guardarCada == 0) _guardar(viaje);
      _publicar(viaje);
    });
  }

  void _suscribirLecturas(ViajeActivo viaje) {
    _lecturas?.cancel();
    _lecturas = _ubicacion.seguir().listen(
      (lectura) {
        _ultimaLecturaRecibida = DateTime.now();
        _ultimaLecturaGps = lectura;
        _calibracion?.gps(lectura);
        _sensores?.gps(lectura);
        if (_procesar(viaje, lectura)) _publicar(viaje);
      },
      // GPS apagado u otro fallo: se muestra "sin señal" y se espera a que vuelva
      onError: (Object _) {},
    );
  }

  /// Distancia y velocidades; si el acumulador acepta la lectura, también la
  /// ruta (mismos filtros de precisión y saltos). `false` si se descartó.
  bool _procesar(ViajeActivo viaje, Lectura lectura) {
    if (!viaje.acumulador.agregar(lectura)) return false;
    viaje.ruta.agregar(lectura);
    return true;
  }

  /// Modo calibración (solo en desarrollo): graba sensores y GPS en un CSV.
  Future<void> _iniciarCalibracion(
    ViajeActivo viaje, {
    required bool nuevo,
  }) async {
    final registro = ref.read(registroCalibracionProvider);
    final activo = await ref.read(modoCalibracionProvider.future);
    // El seguimiento pudo detenerse mientras se leía la preferencia
    final sensores = _sensores;
    if (!activo || !ref.mounted || sensores == null) return;
    _calibracion = registro..iniciar(viaje.recorridoId, nuevo: nuevo);
    sensores.oyente = registro.sensor;
  }

  /// CSV del viaje, si se grabó (también en una sesión anterior de la app).
  Future<String?> _archivoCalibracion(int recorridoId) async {
    if (!kDebugMode) return null;
    final archivo = await ref
        .read(registroCalibracionProvider)
        .archivoDe(recorridoId);
    return archivo?.path;
  }

  void _publicar(ViajeActivo viaje) {
    if (!ref.mounted) return;
    final ahora = DateTime.now();
    state = AsyncData(
      ViajeEnCurso(
        viaje: viaje,
        ahora: ahora,
        sinSenal: ahora.difference(_ultimaLecturaRecibida) > _sinSenalTras,
        lecturaGps: _ultimaLecturaGps,
        avisoPuntual: _avisos.puntual,
        avisoPuntualDesde: _avisos.puntualDesde,
      ),
    );
  }

  void _guardar(ViajeActivo viaje) {
    final usuarioId = _usuarioId;
    if (usuarioId != null) _almacen.guardarViaje(usuarioId, viaje);
  }

  void _detenerSeguimiento() {
    _reloj?.cancel();
    _reloj = null;
    _lecturas?.cancel();
    _lecturas = null;
    _cambiosGps?.cancel();
    _cambiosGps = null;
    _sensores?.detener();
    _sensores = null;
    _calibracion?.detener();
    _calibracion = null;
  }

  Future<Lectura> _posicionActual() async {
    try {
      return await _ubicacion.posicionActual();
    } on TimeoutException {
      throw const ErrorRecorrido(
        'No se pudo obtener tu ubicación. Prueba en un lugar con mejor señal.',
      );
    } on LocationServiceDisabledException {
      throw const ErrorRecorrido('Activa la ubicación del teléfono.');
    } on PermissionDeniedException {
      throw const ErrorRecorrido(
        'DriveSense no tiene permiso para usar tu ubicación.',
      );
    }
  }
}

/// Registra [evento] en [viaje] y, si es nuevo (un evento puntual o el inicio
/// de un exceso), vibra y suena; con [sonido] en `false`, solo vibra.
void registrarYAvisar(
  ViajeActivo viaje,
  EventoRiesgo evento, {
  required GestorAvisos avisos,
  required AvisosEvento servicio,
  required bool sonido,
  required DateTime ahora,
}) {
  final nuevo = viaje.registrarEvento(evento);
  if (avisos.registrar(evento, nuevo: nuevo, ahora: ahora)) {
    servicio.avisar(sonido: sonido);
  }
}

final viajeProvider = AsyncNotifierProvider<ViajeNotifier, EstadoViaje>(
  ViajeNotifier.new,
  retry: (intento, error) => null,
);
