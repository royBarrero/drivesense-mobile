import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../data/navigation_repository.dart';
import '../models/route_plan.dart';

/// Ruta planeada de un origen a un destino (HU-30). Un 401 cierra la sesión.
/// Para reintentar, `ref.invalidate` con el mismo par.
final rutaPlaneadaProvider = FutureProvider.autoDispose
    .family<RutaPlaneada, (Coordenada, Coordenada)>((ref, par) {
      final repositorio = ref.read(navegacionRepositorioProvider);
      return conSesion(ref, () => repositorio.ruta(par.$1, par.$2));
    }, retry: (intento, error) => null);

/// Lugares que coinciden con el texto enviado (sin autocompletar).
final lugaresProvider = FutureProvider.autoDispose.family<List<Lugar>, String>((
  ref,
  texto,
) {
  final repositorio = ref.read(navegacionRepositorioProvider);
  return conSesion(ref, () => repositorio.lugares(texto));
}, retry: (intento, error) => null);
