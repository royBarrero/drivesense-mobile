import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia "Modo aprendizaje" (HU-31), apagada por defecto: consejos
/// breves por voz tras cada evento de riesgo y antes de un giro con velocidad
/// alta. Se cambia en el Copiloto, en la pantalla del viaje y en Perfil.
class ModoAprendizajeNotifier extends AsyncNotifier<bool> {
  static const _clave = 'modo_aprendizaje';

  // Se crea al usarla: el notifier se puede crear sin la plataforma (pruebas)
  late final _preferencias = SharedPreferencesAsync();

  @override
  Future<bool> build() async => await _preferencias.getBool(_clave) ?? false;

  Future<void> cambiar(bool activo) async {
    state = AsyncData(activo);
    await _preferencias.setBool(_clave, activo);
  }
}

final modoAprendizajeProvider =
    AsyncNotifierProvider<ModoAprendizajeNotifier, bool>(
      ModoAprendizajeNotifier.new,
    );
