import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/providers/session_provider.dart';
import '../features/inicio/presentation/home_screen.dart';
import '../features/perfil/presentation/profile_screen.dart';
import '../features/puntaje/presentation/score_history_screen.dart';
import '../features/recorridos/presentation/live_trip_screen.dart';
import '../features/recorridos/presentation/trip_detail_screen.dart';
import '../features/recorridos/presentation/trip_map_screen.dart';
import '../features/recorridos/presentation/trip_summary_screen.dart';
import '../features/recorridos/presentation/trips_screen.dart';
import '../features/recorridos/providers/trip_provider.dart';
import 'main_shell.dart';
import 'placeholder_screens.dart';

abstract final class Rutas {
  static const arranque = '/arranque';
  static const login = '/login';
  static const registro = '/registro';
  static const cambioContrasenia = '/cambio-contrasenia';

  // Pestañas de la barra inferior
  static const inicio = '/inicio';
  static const viajes = '/viajes';
  static const perfil = '/perfil';

  /// Mi DriveScore (HU-17), a pantalla completa (sobre la barra).
  static const miDriveScore = '$inicio/drivescore';

  /// Detalle de un viaje del historial, a pantalla completa (sobre la barra).
  static String detalleViaje(int id) => '$viajes/$id';

  // Recorrido, a pantalla completa (fuera de la barra)
  static const recorrido = '/recorrido';
  static const resumenRecorrido = '/resumen-recorrido';

  /// Mapa completo de un viaje (HU-29): se abre con `push` y los datos en
  /// `extra` (`DatosMapaViaje`), desde el resumen o el detalle.
  static const mapaViaje = '/mapa-viaje';

  /// Rutas que un usuario con sesión no debe ver.
  static const _fueraDeSesion = {arranque, login, registro, cambioContrasenia};
}

final _navegadorRaiz = GlobalKey<NavigatorState>();

/// Las rutas se deciden a partir de `sesionProvider`:
/// comprobando o con error → arranque; sin sesión → login (o registro);
/// con sesión → cambio de contraseña si es temporal; si no, cualquier ruta de la
/// app (desde arranque, login o registro → inicio).
final rutasProvider = Provider<GoRouter>((ref) {
  // Avisa a GoRouter para que vuelva a evaluar `redirect` cuando cambia la sesión
  final cambioSesion = ValueNotifier<int>(0);
  ref.listen(sesionProvider, (_, _) => cambioSesion.value++);

  final router = GoRouter(
    navigatorKey: _navegadorRaiz,
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

      if (usuario.debeCambiarContrasenia) {
        return ruta == Rutas.cambioContrasenia ? null : Rutas.cambioContrasenia;
      }
      return Rutas._fueraDeSesion.contains(ruta) ? Rutas.inicio : null;
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
      StatefulShellRoute.indexedStack(
        builder: (_, _, navegacion) =>
            PantallaPrincipal(navegacion: navegacion),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.inicio,
                builder: (_, _) => const InicioPantalla(),
                routes: [
                  GoRoute(
                    path: 'drivescore',
                    // Tapa la barra inferior; "atrás" vuelve a Inicio
                    parentNavigatorKey: _navegadorRaiz,
                    builder: (_, _) => const MiDriveScorePantalla(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.viajes,
                builder: (_, _) => const ViajesPantalla(),
                routes: [
                  GoRoute(
                    path: ':id',
                    // Tapa la barra inferior; "atrás" vuelve a la lista
                    parentNavigatorKey: _navegadorRaiz,
                    builder: (_, estado) => DetalleViajePantalla(
                      recorridoId: int.parse(estado.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.perfil,
                builder: (_, _) => const PerfilPantalla(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rutas.recorrido,
        builder: (_, _) => const RecorridoEnVivoPantalla(),
      ),
      GoRoute(
        path: Rutas.resumenRecorrido,
        builder: (_, _) => const ResumenRecorridoPantalla(),
      ),
      GoRoute(
        path: Rutas.mapaViaje,
        builder: (_, estado) =>
            MapaViajePantalla(datos: estado.extra! as DatosMapaViaje),
      ),
      GoRoute(
        path: Rutas.cambioContrasenia,
        builder: (_, _) => const CambioContraseniaProvisionalPantalla(),
      ),
    ],
  );

  // Viaje finalizado solo (el auto quedó detenido): se muestra el resumen desde
  // cualquier pantalla; al volver a la app (o tocar la notificación) ya está ahí
  ref.listen(viajeProvider, (anterior, siguiente) {
    final terminado = siguiente.value;
    if (terminado is ViajeTerminado &&
        terminado.automatico &&
        anterior?.value is! ViajeTerminado) {
      router.go(Rutas.resumenRecorrido);
    }
  });

  ref.onDispose(() {
    router.dispose();
    cambioSesion.dispose();
  });
  return router;
});
