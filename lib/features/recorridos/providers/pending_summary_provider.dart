import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../auth/providers/session_provider.dart';
import '../data/trip_local_storage.dart';
import '../data/trips_repository.dart';
import '../models/trip.dart';

enum ResultadoEnvio {
  /// El backend lo recibió (o ya lo tenía: 409).
  enviado,

  /// Sin conexión o error del servidor: se reintenta solo.
  pendiente,

  /// 404/422: el backend nunca lo aceptará, se descarta.
  rechazado,
}

class Envio {
  const Envio(this.resultado, {this.recorrido, this.mensaje});

  final ResultadoEnvio resultado;

  /// Respuesta del backend; nula si el envío no fue un 200.
  final Recorrido? recorrido;

  /// Motivo del rechazo.
  final String? mensaje;
}

/// Resumen de un viaje finalizado que aún no llegó al backend (o `null`).
///
/// Se reintenta al abrir la app, al volver del segundo plano y cada 30 s.
class ResumenPendienteNotifier extends AsyncNotifier<ResumenRecorrido?> {
  static const intervaloReintento = Duration(seconds: 30);

  Future<Envio?>? _envioEnCurso;

  int? get _usuarioId => ref.read(sesionProvider).value?.id;

  @override
  Future<ResumenRecorrido?> build() async {
    final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
    if (usuarioId == null) return null;

    final temporizador = Timer.periodic(intervaloReintento, (_) {
      if (state.value != null) enviar();
    });
    final ciclo = AppLifecycleListener(onResume: enviar);
    ref.onDispose(() {
      temporizador.cancel();
      ciclo.dispose();
    });

    final pendiente = await ref
        .read(almacenRecorridoProvider)
        .leerResumen(usuarioId);
    if (pendiente != null) Future.microtask(enviar);
    return pendiente;
  }

  /// Lo deja guardado en el teléfono antes de intentar enviarlo.
  Future<void> guardar(ResumenRecorrido resumen) async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return;
    await ref.read(almacenRecorridoProvider).guardarResumen(usuarioId, resumen);
    state = AsyncData(resumen);
  }

  /// Envía el resumen pendiente; `null` si no había ninguno.
  /// Si ya hay un envío en marcha, devuelve ese mismo.
  Future<Envio?> enviar() =>
      _envioEnCurso ??= _enviar().whenComplete(() => _envioEnCurso = null);

  Future<Envio?> _enviar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return null;
    // Se leen antes de esperar: si se cierra sesión a mitad, `ref` ya no sirve
    final almacen = ref.read(almacenRecorridoProvider);
    final repositorio = ref.read(recorridosRepositorioProvider);
    final sesion = ref.read(sesionProvider.notifier);
    final resumen = await almacen.leerResumen(usuarioId);
    if (resumen == null) return null;

    Future<void> borrar() async {
      await almacen.borrarResumen(usuarioId);
      if (ref.mounted) state = const AsyncData(null);
    }

    try {
      final recorrido = await repositorio.finalizar(resumen);
      await borrar();
      return Envio(ResultadoEnvio.enviado, recorrido: recorrido);
    } on ErrorApi catch (e) {
      switch (e.codigo) {
        case 409:
          // Ya estaba finalizado (p. ej. la respuesta anterior se perdió)
          await borrar();
          return const Envio(ResultadoEnvio.enviado);
        case 404 || 422:
          await borrar();
          return Envio(ResultadoEnvio.rechazado, mensaje: e.mensaje);
        case 401:
          // Se conserva: se enviará cuando esta cuenta vuelva a iniciar sesión
          await sesion.cerrarSesion();
          return const Envio(ResultadoEnvio.pendiente);
        default:
          return const Envio(ResultadoEnvio.pendiente);
      }
    }
  }
}

final resumenPendienteProvider =
    AsyncNotifierProvider<ResumenPendienteNotifier, ResumenRecorrido?>(
      ResumenPendienteNotifier.new,
      retry: (intento, error) => null,
    );
