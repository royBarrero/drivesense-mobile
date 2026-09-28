import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_error.dart';
import '../../auth/providers/session_provider.dart';
import '../data/location_service.dart';
import '../data/trip_local_storage.dart';
import '../data/trips_repository.dart';
import '../models/trip.dart';
import '../models/trip_accumulator.dart';
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
  });

  final ViajeActivo viaje;
  final DateTime ahora;

  /// No llegan lecturas del GPS (apagado, sin cielo despejado...).
  final bool sinSenal;

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
  const ViajeTerminado(this.resumen, this.resultado, {this.mensaje});

  final ResumenRecorrido resumen;
  final ResultadoViaje resultado;

  /// Motivo si el backend lo rechazó.
  final String? mensaje;
}

/// Recorrido del conductor (HU-04 y HU-05).
class ViajeNotifier extends AsyncNotifier<EstadoViaje> {
  static const _sinSenalTras = Duration(seconds: 10);
  static const _guardarCada = 5; // segundos

  StreamSubscription<Lectura>? _lecturas;
  StreamSubscription<bool>? _cambiosGps;
  Timer? _reloj;
  int _segundos = 0;
  DateTime _ultimaLecturaRecibida = DateTime.now();

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
    viaje.acumulador.agregar(partida);
    await _almacen.guardarViaje(usuarioId, viaje);
    _comenzarSeguimiento(viaje);
  }

  /// Retoma un viaje interrumpido. El tramo sin registrar no suma distancia;
  /// el cronómetro sigue contando desde el inicio.
  void continuar() {
    final actual = state.value;
    if (actual is ViajeInterrumpido) _comenzarSeguimiento(actual.viaje);
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
    _detenerSeguimiento();

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
      ResultadoEnvio.enviado => ViajeTerminado(
        resumen,
        envio!.recorrido?.estado == EstadoRecorrido.descartado
            ? ResultadoViaje.descartado
            : ResultadoViaje.finalizado,
      ),
      ResultadoEnvio.rechazado => ViajeTerminado(
        resumen,
        ResultadoViaje.rechazado,
        mensaje: envio!.mensaje,
      ),
      ResultadoEnvio.pendiente ||
      null => ViajeTerminado(resumen, ResultadoViaje.pendiente),
    });
  }

  /// Sale de la pantalla de resumen.
  void cerrarResumen() {
    if (state.value is ViajeTerminado) state = const AsyncData(SinViaje());
  }

  void _comenzarSeguimiento(ViajeActivo viaje) {
    _detenerSeguimiento();
    _segundos = 0;
    _ultimaLecturaRecibida = DateTime.now();
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
        if (viaje.acumulador.agregar(lectura)) _publicar(viaje);
      },
      // GPS apagado u otro fallo: se muestra "sin señal" y se espera a que vuelva
      onError: (Object _) {},
    );
  }

  void _publicar(ViajeActivo viaje) {
    if (!ref.mounted) return;
    final ahora = DateTime.now();
    state = AsyncData(
      ViajeEnCurso(
        viaje: viaje,
        ahora: ahora,
        sinSenal: ahora.difference(_ultimaLecturaRecibida) > _sinSenalTras,
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

final viajeProvider = AsyncNotifierProvider<ViajeNotifier, EstadoViaje>(
  ViajeNotifier.new,
  retry: (intento, error) => null,
);
