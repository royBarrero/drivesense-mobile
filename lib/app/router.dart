import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/providers/session_provider.dart';
import 'placeholder_screens.dart';

abstract final class Rutas {
  static const arranque = '/arranque';
  static const login = '/login';
  static const registro = '/registro';
  static const inicio = '/inicio';
  static const cambioContrasenia = '/cambio-contrasenia';
}

/// Las rutas se deciden a partir de `sesionProvider`:
/// comprobando o con error → arranque; sin sesión → login (o registro);
/// con sesión → cambio de contraseña si es temporal, si no → inicio.
final rutasProvider = Provider<GoRouter>((ref) {
  // Avisa a GoRouter para que vuelva a evaluar `redirect` cuando cambia la sesión
  final cambioSesion = ValueNotifier<int>(0);
  ref.listen(sesionProvider, (_, _) => cambioSesion.value++);

  final router = GoRouter(
    initialLocation: Rutas.arranque,
    refreshListenable: cambioSesion,
    redirect: (context, estado) {
      final sesion = ref.read(sesionProvider);
      final ruta = estado.matchedLocation;

      if (sesion.isLoading || sesion.hasError) {
        return ruta == Rutas.arranque ? null : Rutas.arranque;
      }

      final usuario = sesion.value;
      if (usuario == null) {
        return ruta == Rutas.login || ruta == Rutas.registro
            ? null
            : Rutas.login;
      }

      final destino = usuario.debeCambiarContrasenia
          ? Rutas.cambioContrasenia
          : Rutas.inicio;
      return ruta == destino ? null : destino;
    },
    routes: [
      GoRoute(
        path: Rutas.arranque,
        builder: (_, _) => const ArranquePantalla(),
      ),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPantalla()),
      GoRoute(
        path: Rutas.registro,
        builder: (_, _) => const RegistroPantalla(),
      ),
      GoRoute(
        path: Rutas.inicio,
        builder: (_, _) => const InicioProvisionalPantalla(),
      ),
      GoRoute(
        path: Rutas.cambioContrasenia,
        builder: (_, _) => const CambioContraseniaProvisionalPantalla(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    cambioSesion.dispose();
  });
  return router;
});
