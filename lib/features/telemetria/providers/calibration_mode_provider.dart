import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia "modo calibración" (solo en la versión de desarrollo; en release
/// siempre está desactivado). Se activa desde el Perfil y aplica al siguiente viaje.
class ModoCalibracionNotifier extends AsyncNotifier<bool> {
  static const _clave = 'modo_calibracion';

  final _preferencias = SharedPreferencesAsync();

  @override
  Future<bool> build() async {
    if (!kDebugMode) return false;
    return await _preferencias.getBool(_clave) ?? false;
  }

  Future<void> cambiar(bool activo) async {
    if (!kDebugMode) return;
    await _preferencias.setBool(_clave, activo);
    state = AsyncData(activo);
  }
}

final modoCalibracionProvider =
    AsyncNotifierProvider<ModoCalibracionNotifier, bool>(
      ModoCalibracionNotifier.new,
    );
