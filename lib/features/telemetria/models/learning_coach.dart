/// Modo aprendizaje (HU-31): consejos breves por voz tras cada evento de
/// riesgo y antes de un giro con velocidad alta. Dart puro. No cambia el
/// DriveScore ni los avisos visuales de HU-14.
library;

import '../../navegacion/models/route_plan.dart';
import '../../navegacion/models/route_progress.dart';
import 'event_detector.dart';

/// Frases fijas (en el CLAUDE.md): generales, sin velocidades exactas ni
/// distancias a otros vehículos.
abstract final class FrasesAprendizaje {
  static const frenada =
      'Frenaste fuerte. Mira más lejos y suelta el acelerador antes para frenar '
      'con suavidad.';
  static const aceleracion =
      'Aceleraste fuerte. Pisa el acelerador de a poco al arrancar.';
  static const giro =
      'Giro brusco. Reduce la velocidad antes de entrar a la curva.';
  static const exceso =
      'Fuiste sobre el límite. Mantén una velocidad constante y segura.';
  static const giroConVelocidad = 'Se acerca un giro: reduce la velocidad.';

  static String de(TipoEvento tipo) => switch (tipo) {
    TipoEvento.frenadaBrusca => frenada,
    TipoEvento.aceleracionSevera => aceleracion,
    TipoEvento.giroAgresivo => giro,
    TipoEvento.excesoVelocidad => exceso,
  };
}

/// Maniobras que cuentan para "reduce antes del giro": los giros normales y
/// cerrados, la media vuelta y la rotonda (no los leves ni seguir derecho).
const tiposGiro = {
  TipoPaso.girarIzquierda,
  TipoPaso.girarDerecha,
  TipoPaso.girarFuerteIzquierda,
  TipoPaso.girarFuerteDerecha,
  TipoPaso.mediaVuelta,
  TipoPaso.entrarRotonda,
};

/// Decide qué consejo decir y cuándo:
/// - Frenada, aceleración y giro: [UmbralesCopiloto.consejoTrasManiobra]
///   después del evento, si no hubo otro del mismo tipo (la maniobra terminó).
/// - Exceso de velocidad: cuando el tramo se cierra.
/// - Giro con velocidad: una vez por maniobra de la ruta.
/// - Como mucho uno cada [UmbralesCopiloto.entreConsejos]; uno que toca
///   durante una indicación de ruta o antes de ese tiempo se descarta.
class ConsejeroAprendizaje {
  final _pendientes = <TipoEvento, DateTime>{};
  final _girosAvisados = <int>{};
  DateTime? _ultimoConsejo;
  DateTime? _ultimaIndicacion;

  /// Ruta nueva (recálculo): los índices de las maniobras cambian.
  void nuevaRuta() => _girosAvisados.clear();

  /// El Copiloto acaba de decir una indicación de ruta.
  void indicacionDicha(DateTime ahora) => _ultimaIndicacion = ahora;

  /// Un evento nuevo o actualizado del detector (HU-10 a HU-13).
  void registrar(EventoRiesgo evento, DateTime ahora) {
    if (evento.tipo == TipoEvento.excesoVelocidad) {
      if (evento.enCurso) {
        _pendientes.remove(TipoEvento.excesoVelocidad);
      } else {
        // Se cerró el tramo: ya se puede decir
        _pendientes[TipoEvento.excesoVelocidad] = ahora.subtract(
          UmbralesCopiloto.consejoTrasManiobra,
        );
      }
      return;
    }
    // Otro del mismo tipo reinicia la espera: la maniobra sigue
    _pendientes[evento.tipo] = ahora;
  }

  /// Con el reloj de 1 s: el consejo de un evento cuya maniobra ya terminó, o
  /// `null`.
  String? revisar(DateTime ahora) {
    final listos = [
      for (final MapEntry(:key, :value) in _pendientes.entries)
        if (ahora.difference(value) >= UmbralesCopiloto.consejoTrasManiobra)
          key,
    ];
    if (listos.isEmpty) return null;
    for (final tipo in listos) {
      _pendientes.remove(tipo);
    }
    // Si terminaron varios a la vez, se dice el primero según el orden de riesgo
    final tipo = _porRiesgo.firstWhere(listos.contains);
    return _decir(FrasesAprendizaje.de(tipo), ahora);
  }

  /// Con cada lectura de un viaje con destino: si se acerca a un giro con
  /// velocidad alta, el consejo (una vez por maniobra).
  String? acercamiento({
    required ProgresoRuta progreso,
    required double velocidadKmh,
    required DateTime ahora,
  }) {
    final proxima = progreso.proxima;
    final indice = progreso.indiceProxima;
    if (proxima == null || indice == null) return null;
    if (!tiposGiro.contains(proxima.tipo)) return null;
    if (progreso.hastaProximaM > UmbralesCopiloto.giroDistanciaM) return null;
    if (velocidadKmh < UmbralesCopiloto.giroVelocidadKmh) return null;
    if (!_girosAvisados.add(indice)) return null;
    return _decir(FrasesAprendizaje.giroConVelocidad, ahora);
  }

  String? _decir(String frase, DateTime ahora) {
    final indicacion = _ultimaIndicacion;
    if (indicacion != null &&
        ahora.difference(indicacion) <
            UmbralesCopiloto.silencioTrasIndicacion) {
      return null;
    }
    final ultimo = _ultimoConsejo;
    if (ultimo != null &&
        ahora.difference(ultimo) < UmbralesCopiloto.entreConsejos) {
      return null;
    }
    _ultimoConsejo = ahora;
    return frase;
  }

  /// Mismo orden que la recomendación del backend (HU-18).
  static const _porRiesgo = [
    TipoEvento.excesoVelocidad,
    TipoEvento.frenadaBrusca,
    TipoEvento.giroAgresivo,
    TipoEvento.aceleracionSevera,
  ];
}
