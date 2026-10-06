import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia "Sonido de avisos" (HU-14), activada por defecto. Silenciada,
/// los eventos solo vibran. Se cambia desde el Perfil, también durante un viaje.
class SonidoAvisosNotifier extends AsyncNotifier<bool> {
  static const _clave = 'sonido_avisos';

  final _preferencias = SharedPreferencesAsync();

  @override
  Future<bool> build() async => await _preferencias.getBool(_clave) ?? true;

  Future<void> cambiar(bool activo) async {
    await _preferencias.setBool(_clave, activo);
    state = AsyncData(activo);
  }
}

final sonidoAvisosProvider = AsyncNotifierProvider<SonidoAvisosNotifier, bool>(
  SonidoAvisosNotifier.new,
);
