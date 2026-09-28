import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

import '../../../core/design/colors.dart';
import '../models/trip_accumulator.dart';

/// Resultado de preparar la ubicación antes de iniciar o continuar un viaje.
enum EstadoUbicacion { lista, permisoDenegado, permisoBloqueado, gpsApagado }

/// GPS y permisos del recorrido (envuelve geolocator y permission_handler).
class ServicioUbicacion {
  /// ¿Ya están concedidos los permisos? (para no mostrar la explicación de nuevo).
  Future<bool> permisosConcedidos() async {
    final ubicacion = await Geolocator.checkPermission();
    final notificaciones = await Permission.notification.status;
    return (ubicacion == LocationPermission.whileInUse ||
            ubicacion == LocationPermission.always) &&
        !notificaciones.isDenied;
  }

  /// Pide los permisos que falten y comprueba que el GPS esté encendido.
  ///
  /// El de notificaciones no es obligatorio: sin él el viaje se registra igual,
  /// solo que no se ve el aviso fijo.
  Future<EstadoUbicacion> preparar() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) {
      return EstadoUbicacion.permisoBloqueado;
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.unableToDetermine) {
      return EstadoUbicacion.permisoDenegado;
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return EstadoUbicacion.gpsApagado;
    }
    return EstadoUbicacion.lista;
  }

  Future<bool> abrirAjustesApp() => Geolocator.openAppSettings();

  Future<bool> abrirAjustesUbicacion() => Geolocator.openLocationSettings();

  /// Posición actual para el punto de partida.
  Future<Lectura> posicionActual() async {
    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      ),
    );
    return _lectura(posicion);
  }

  /// Lecturas cada segundo. Mientras haya alguien escuchando, corre como servicio
  /// en primer plano con una notificación fija: sigue con la pantalla apagada o la
  /// app en segundo plano.
  Stream<Lectura> seguir() {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Viaje en curso',
          notificationText: 'DriveSense está registrando tu recorrido',
          notificationChannelName: 'Recorridos',
          notificationIcon: const AndroidResource(name: 'ic_notificacion'),
          color: ColoresDriveSense.claro.primario,
          setOngoing: true,
          // Sin wakelock, con la pantalla apagada las lecturas llegan en bloque
          enableWakeLock: true,
        ),
      ),
    ).map(_lectura);
  }

  /// Avisa cuando el usuario enciende o apaga el GPS.
  Stream<bool> cambiosGps() => Geolocator.getServiceStatusStream().map(
    (estado) => estado == ServiceStatus.enabled,
  );

  Lectura _lectura(Position posicion) => Lectura(
    latitud: posicion.latitude,
    longitud: posicion.longitude,
    precisionM: posicion.accuracy,
    velocidadMs: posicion.speed,
    fecha: posicion.timestamp,
  );
}

final servicioUbicacionProvider = Provider<ServicioUbicacion>(
  (ref) => ServicioUbicacion(),
);
