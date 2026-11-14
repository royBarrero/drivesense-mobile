import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../data/gamification_repository.dart';
import '../models/progress.dart';

/// Nivel, puntos y logros del conductor (HU-21); `null` sin sesión.
///
/// `ResumenPendienteNotifier` lo invalida cuando el backend recibe un viaje.
final progresoProvider = FutureProvider<ProgresoConductor?>((ref) async {
  final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
  if (usuarioId == null) return null;
  final repositorio = ref.read(gamificacionRepositorioProvider);
  return conSesion(ref, repositorio.progreso);
}, retry: (intento, error) => null);
