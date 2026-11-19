import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../../recorridos/models/trip.dart';
import '../../recorridos/models/trip_accumulator.dart';
import '../../telemetria/data/voice_service.dart';
import '../../telemetria/models/event_detector.dart';
import '../../telemetria/models/learning_coach.dart';
import '../../telemetria/providers/learning_mode_provider.dart';
import '../data/navigation_repository.dart';
import '../models/route_plan.dart';
import '../models/route_progress.dart';
import '../models/voice_guide.dart';

/// Lo que muestra la pantalla del viaje con Copiloto (HU-31).
class EstadoCopiloto {
  const EstadoCopiloto({
    this.destino,
    this.ruta,
    this.progreso,
    this.recalculando = false,
    this.sinConexion = false,
    this.sinRuta = false,
    this.llego = false,
    this.silenciado = false,
  });

  /// Nulo en un recorrido libre (solo funciona el Modo aprendizaje).
  final Destino? destino;
  final RutaPlaneada? ruta;
  final ProgresoRuta? progreso;

  /// Pidiendo la ruta (al empezar o tras un desvío).
  final bool recalculando;

  /// El último pedido de ruta falló por la conexión: sigue con la anterior.
  final bool sinConexion;

  /// No hay ruta que seguir (no se pudo calcular): el viaje sigue igual.
  final bool sinRuta;

  final bool llego;

  /// Voz silenciada en este viaje (guía y consejos).
  final bool silenciado;

  EstadoCopiloto copyWith({
    RutaPlaneada? ruta,
    ProgresoRuta? progreso,
    bool? recalculando,
    bool? sinConexion,
    bool? sinRuta,
    bool? llego,
    bool? silenciado,
  }) => EstadoCopiloto(
    destino: destino,
    ruta: ruta ?? this.ruta,
    progreso: progreso ?? this.progreso,
    recalculando: recalculando ?? this.recalculando,
    sinConexion: sinConexion ?? this.sinConexion,
    sinRuta: sinRuta ?? this.sinRuta,
    llego: llego ?? this.llego,
    silenciado: silenciado ?? this.silenciado,
  );
}

/// Copiloto por voz y Modo aprendizaje durante un viaje (HU-31).
///
/// Lo maneja `ViajeNotifier`: [comenzar] al iniciar o continuar, [lectura] con
/// cada lectura aceptada del GPS, [evento] con cada evento del detector,
/// [segundo] con el reloj del viaje y [terminar] al detener el seguimiento.
/// Nulo fuera de un viaje.
class CopilotoNotifier extends Notifier<EstadoCopiloto?> {
  /// Para las pruebas (el reloj del viaje usa la hora real).
  DateTime Function() reloj = DateTime.now;

  SeguidorRuta? _seguidor;
  final _guia = GuiaVoz();
  final _consejero = ConsejeroAprendizaje();
  final _desvio = DetectorDesvio();
  DateTime? _ultimoPedido;
  bool _pidiendo = false;
  bool _sinConexionAvisado = false;
  bool _desviado = false;

  /// Se leen al empezar: en `terminar` (desde `onDispose`) no se puede usar `ref`.
  VozCopiloto? _voz;

  @override
  EstadoCopiloto? build() => null;

  /// Empieza a guiar [viaje]. Con [ruta] (la que ya calculó el Copiloto) no la
  /// vuelve a pedir; sin ella, la pide con la primera lectura.
  void comenzar(ViajeActivo viaje, {RutaPlaneada? ruta}) {
    _voz = ref.read(vozCopilotoProvider);
    // Se carga ya: el primer evento debe respetar la preferencia
    ref.read(modoAprendizajeProvider);
    _guia.nuevaRuta();
    _consejero.nuevaRuta();
    _desvio.reiniciar();
    _ultimoPedido = null;
    _pidiendo = false;
    _sinConexionAvisado = false;
    _desviado = false;
    _seguidor = ruta == null ? null : SeguidorRuta(ruta);
    state = EstadoCopiloto(destino: viaje.destino, ruta: ruta);
  }

  void terminar() {
    _seguidor = null;
    _voz?.callar();
    if (ref.mounted) state = null;
  }

  void silenciar(bool silenciado) {
    final actual = state;
    if (actual == null) return;
    state = actual.copyWith(silenciado: silenciado);
    if (silenciado) _voz?.callar();
  }

  bool get _aprendizaje => ref.read(modoAprendizajeProvider).value ?? false;

  void evento(EventoRiesgo evento) {
    if (state == null || !_aprendizaje) return;
    _consejero.registrar(evento, reloj());
  }

  void segundo() {
    if (state == null || !_aprendizaje) return;
    final consejo = _consejero.revisar(reloj());
    if (consejo != null) _hablar(consejo, prioridad: false);
  }

  void lectura(Lectura lectura, {required double velocidadKmh}) {
    final actual = state;
    final destino = actual?.destino;
    if (actual == null || destino == null || actual.llego) return;
    final ahora = reloj();
    final posicion = Coordenada(lectura.latitud, lectura.longitud);
    final seguidor = _seguidor;

    if (seguidor == null) {
      // Sin ruta todavía (continuar un viaje) o tras un fallo: se pide
      _pedirRuta(posicion, destino, desvio: false);
      return;
    }

    final progreso = seguidor.actualizar(posicion);
    final desviado = _desvio.evaluar(
      distanciaARutaM: progreso.distanciaARutaM,
      precisionM: lectura.precisionM,
      ahora: ahora,
    );
    if (desviado) {
      if (!_desviado) {
        _desviado = true;
        _hablar(FrasesCopiloto.desvio, prioridad: true);
      }
      state = actual.copyWith(progreso: progreso);
      _pedirRuta(posicion, destino, desvio: true);
      return;
    }
    _desviado = false;

    final indicacion = _guia.evaluar(progreso, seguidor);
    if (indicacion != null) {
      _hablar(indicacion, prioridad: true);
      _consejero.indicacionDicha(ahora);
    }
    if (_aprendizaje) {
      final consejo = _consejero.acercamiento(
        progreso: progreso,
        velocidadKmh: velocidadKmh,
        ahora: ahora,
      );
      if (consejo != null) _hablar(consejo, prioridad: false);
    }
    state = actual.copyWith(progreso: progreso, llego: _guia.llegadaDicha);
  }

  /// Pide la ruta desde [desde], como mucho cada
  /// [UmbralesCopiloto.recalculoMinimo].
  Future<void> _pedirRuta(
    Coordenada desde,
    Destino destino, {
    required bool desvio,
  }) async {
    final ahora = reloj();
    final ultimo = _ultimoPedido;
    if (_pidiendo ||
        (ultimo != null &&
            ahora.difference(ultimo) < UmbralesCopiloto.recalculoMinimo)) {
      return;
    }
    _pidiendo = true;
    _ultimoPedido = ahora;
    final inicial = _seguidor == null && !desvio;
    state = state?.copyWith(recalculando: true);
    try {
      final repositorio = ref.read(navegacionRepositorioProvider);
      final ruta = await conSesion(
        ref,
        () => repositorio.ruta(desde, destino.posicion),
      );
      if (!ref.mounted || state == null) return;
      _seguidor = SeguidorRuta(ruta);
      _guia.nuevaRuta();
      _consejero.nuevaRuta();
      _desvio.reiniciar();
      _desviado = false;
      _sinConexionAvisado = false;
      state = state!.copyWith(
        ruta: ruta,
        recalculando: false,
        sinConexion: false,
        sinRuta: false,
      );
      if (desvio) _hablar(FrasesCopiloto.rutaActualizada, prioridad: true);
    } on Object catch (error) {
      if (!ref.mounted || state == null) return;
      final sinConexion =
          error is ErrorNavegacion &&
          error.motivo == MotivoErrorNavegacion.sinConexion;
      state = state!.copyWith(
        recalculando: false,
        sinConexion: sinConexion,
        sinRuta: _seguidor == null,
      );
      // Un aviso por corte, hasta que vuelva a calcularse una ruta
      if (!_sinConexionAvisado) {
        _sinConexionAvisado = true;
        _hablar(
          inicial || _seguidor == null
              ? FrasesCopiloto.sinRutaAlContinuar
              : FrasesCopiloto.sinConexionRecalcular,
          prioridad: true,
        );
      }
    } finally {
      _pidiendo = false;
    }
  }

  void _hablar(String texto, {required bool prioridad}) {
    if (state?.silenciado ?? false) return;
    _voz?.hablar(texto, prioridad: prioridad);
  }
}

final copilotoProvider = NotifierProvider<CopilotoNotifier, EstadoCopiloto?>(
  CopilotoNotifier.new,
);
