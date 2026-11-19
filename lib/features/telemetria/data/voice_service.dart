import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Voz del Copiloto y del Modo aprendizaje (HU-31).
///
/// Habla Android (`MainActivity.hablar`, `TextToSpeech` en español): como los
/// avisos de HU-14, sigue funcionando con la pantalla apagada porque el
/// servicio en primer plano de geolocator mantiene vivo el proceso.
class VozCopiloto {
  static const _canal = MethodChannel('drivesense/sistema');

  /// Con [prioridad] (indicaciones de ruta) corta lo que se estaba diciendo;
  /// sin ella (consejos) espera su turno.
  Future<void> hablar(String texto, {bool prioridad = false}) async {
    try {
      await _canal.invokeMethod<void>('hablar', {
        'texto': texto,
        'prioridad': prioridad,
      });
    } on Object {
      // Una voz que falla no debe interrumpir el registro del viaje
    }
  }

  /// Corta lo que se esté diciendo (al silenciar).
  Future<void> callar() async {
    try {
      await _canal.invokeMethod<void>('callarVoz');
    } on Object {
      // Igual que [hablar]
    }
  }
}

final vozCopilotoProvider = Provider<VozCopiloto>((ref) => VozCopiloto());
