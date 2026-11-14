import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../../recorridos/models/trip_history.dart';
import '../data/gamification_repository.dart';
import '../models/weekly_challenges.dart';

/// Desafíos de la semana en curso (HU-22); `null` sin sesión. La semana empieza
/// el lunes 00:00 local, como el historial.
///
/// `ResumenPendienteNotifier` lo invalida cuando el backend recibe un viaje.
final desafiosProvider = FutureProvider<DesafiosSemana?>((ref) async {
  final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
  if (usuarioId == null) return null;
  final repositorio = ref.read(gamificacionRepositorioProvider);
  return conSesion(
    ref,
    () => repositorio.desafios(
      desde: PeriodoHistorial.semana.desde(DateTime.now())!,
    ),
  );
}, retry: (intento, error) => null);
