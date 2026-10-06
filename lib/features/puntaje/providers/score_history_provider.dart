import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../data/score_repository.dart';
import '../models/score_history.dart';

/// Histórico del DriveScore de un periodo (HU-17); `null` sin sesión.
///
/// `ResumenPendienteNotifier` lo invalida cuando el backend recibe un viaje,
/// así Inicio y Mi DriveScore se actualizan al finalizar.
final historicoPuntajeProvider =
    FutureProvider.family<HistoricoPuntaje?, PeriodoPuntaje>((
      ref,
      periodo,
    ) async {
      final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
      if (usuarioId == null) return null;
      final repositorio = ref.read(puntajeRepositorioProvider);
      return conSesion(
        ref,
        () => repositorio.historico(desde: periodo.desde(DateTime.now())),
      );
    }, retry: (intento, error) => null);
