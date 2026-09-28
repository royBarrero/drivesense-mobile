import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/api/api_error.dart';
import '../data/auth_repository.dart';
import '../data/user_storage.dart';
import '../models/user.dart';

/// Sesión actual: el usuario autenticado, o `null` si no hay sesión.
///
/// Las rutas dependen de este estado (lib/app/router.dart).
class SesionNotifier extends AsyncNotifier<Usuario?> {
  @override
  Future<Usuario?> build() async {
    final almacen = ref.read(almacenTokenProvider);
    final usuarios = ref.read(almacenUsuarioProvider);
    if (await almacen.leer() == null) return null;

    try {
      final usuario = await ref
          .read(authRepositorioProvider)
          .obtenerUsuarioActual();
      await usuarios.guardar(usuario);
      return usuario;
    } on ErrorApi catch (e) {
      if (e.codigo == 401) {
        // Token inválido o expirado
        await almacen.borrar();
        await usuarios.borrar();
        return null;
      }
      // Sin conexión o servidor caído: se entra con el último usuario conocido
      // (p. ej. para continuar un viaje sin señal). Un 401 posterior cierra la sesión.
      final sinServidor = e.codigo == null || e.codigo! >= 500;
      final guardado = sinServidor ? await usuarios.leer() : null;
      if (guardado != null) return guardado;
      // Sin usuario guardado: se conserva el token y el arranque ofrece reintentar
      rethrow;
    }
  }

  /// Lanza `ErrorApi` si el login falla; la pantalla muestra su mensaje.
  Future<void> iniciarSesion({
    required String email,
    required String contrasenia,
  }) async {
    final sesion = await ref
        .read(authRepositorioProvider)
        .iniciarSesion(email: email, contrasenia: contrasenia);
    await _abrirSesion(sesion);
  }

  /// Registro de conductor (HU-01): deja la sesión iniciada.
  /// Lanza `ErrorApi` si falla; la pantalla muestra su mensaje.
  Future<void> registrarse({
    required String nombre,
    required String email,
    required String telefono,
    required String contrasenia,
  }) async {
    final sesion = await ref
        .read(authRepositorioProvider)
        .registrar(
          nombre: nombre,
          email: email,
          telefono: telefono,
          contrasenia: contrasenia,
        );
    await _abrirSesion(sesion);
  }

  Future<void> _abrirSesion(Sesion sesion) async {
    await ref.read(almacenTokenProvider).guardar(sesion.token);
    await ref.read(almacenUsuarioProvider).guardar(sesion.usuario);
    state = AsyncData(sesion.usuario);
  }

  Future<void> cerrarSesion() async {
    await ref.read(almacenTokenProvider).borrar();
    await ref.read(almacenUsuarioProvider).borrar();
    state = const AsyncData(null);
  }

  /// Vuelve a comprobar el token guardado (botón "Reintentar" del arranque).
  void reintentar() => ref.invalidateSelf();
}

final sesionProvider = AsyncNotifierProvider<SesionNotifier, Usuario?>(
  SesionNotifier.new,
  // Sin reintentos automáticos de Riverpod: el arranque muestra el error y un botón "Reintentar"
  retry: (intento, error) => null,
);
