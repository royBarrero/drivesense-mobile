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
}

final avisosEventoProvider = Provider<AvisosEvento>((ref) => AvisosEvento());
