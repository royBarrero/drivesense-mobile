import 'package:flutter/services.dart';

/// Canal con `MainActivity.kt`.
const _canal = MethodChannel('drivesense/sistema');

/// Manda la app al fondo sin cerrar la actividad (como "Inicio" del teléfono).
///
/// Cerrarla con "Atrás" detendría el servicio de ubicación de un viaje en curso.
Future<void> enviarAppAlFondo() => _canal.invokeMethod<void>('enviarAlFondo');

/// [abrir] se llama cuando el conductor toca la notificación de un evento de
/// riesgo (`MainActivity.onNewIntent`). Con `null` deja de escuchar.
void alTocarNotificacionEvento(void Function()? abrir) {
  _canal.setMethodCallHandler(
    abrir == null
        ? null
        : (llamada) async {
            if (llamada.method == 'abrirRecorrido') abrir();
          },
  );
}
