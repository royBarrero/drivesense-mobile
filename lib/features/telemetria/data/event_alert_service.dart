import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vibración y sonido corto de cada evento nuevo (HU-14).
///
/// Lo hace Android (`MainActivity.avisarEvento`): el proceso sigue vivo con la
/// pantalla apagada gracias al servicio en primer plano de geolocator, así que
/// el aviso también sale con la pantalla apagada.
class AvisosEvento {
  static const _canal = MethodChannel('drivesense/sistema');

  /// Con [sonido] en `false` solo vibra.
  Future<void> avisar({required bool sonido}) async {
    try {
      await _canal.invokeMethod<void>('avisarEvento', {'sonido': sonido});
    } on Object {
      // Un aviso que falla no debe interrumpir el registro del viaje
    }
  }

  /// Notificación del sistema del evento (`MainActivity.notificarEvento`,
  /// canal "Eventos de riesgo"): emergente, también con la pantalla bloqueada.
  /// Es silenciosa: la vibración y el sonido los pone [avisar]. Al tocarla se
  /// abre la pantalla del recorrido. Una nueva reemplaza a la anterior.
  Future<void> notificar({
    required String titulo,
    required String texto,
  }) async {
    try {
      await _canal.invokeMethod<void>('notificarEvento', {
        'titulo': titulo,
        'texto': texto,
      });
    } on Object {
      // Sin permiso o con el canal silenciado el viaje sigue igual
    }
  }

  /// Quita la notificación del último evento (al finalizar el viaje).
  Future<void> quitarNotificacion() async {
    try {
      await _canal.invokeMethod<void>('quitarNotificacionEvento');
    } on Object {
      // Si queda, se borra al tocarla
    }
  }
}

final avisosEventoProvider = Provider<AvisosEvento>((ref) => AvisosEvento());
