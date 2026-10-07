import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_accumulator.dart';

/// Notificación de viaje finalizado solo (el auto quedó detenido).
///
/// La muestra Android (`MainActivity.notificarViajeFinalizado`): sale también
/// con la pantalla apagada o la app en segundo plano. Al tocarla se abre la app,
/// que ya está en el resumen.
class AvisoViajeFinalizado {
  static const _canal = MethodChannel('drivesense/sistema');

  Future<void> notificar() async {
    final minutos = UmbralesRecorrido.detenidoParaFinalizar.inMinutes;
    try {
      await _canal.invokeMethod<void>('notificarViajeFinalizado', {
        'titulo': 'Tu viaje terminó',
        'texto':
            'Estuviste detenido $minutos min, así que lo finalizamos. '
            'Toca para ver el resumen.',
      });
    } on Object {
      // Sin aviso el viaje igual queda finalizado y guardado
    }
  }
}

final avisoViajeFinalizadoProvider = Provider<AvisoViajeFinalizado>(
  (ref) => AvisoViajeFinalizado(),
);
