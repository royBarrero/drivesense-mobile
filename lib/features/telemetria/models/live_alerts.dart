import 'event_detector.dart';

/// Tiempos de los avisos en vivo (HU-14).
abstract final class UmbralesAviso {
  /// Lo que se muestra un evento puntual (frenada, aceleración o giro).
  static const duracionPuntual = Duration(seconds: 4);
}

/// Decide qué eventos avisan (vibración y sonido) y recuerda el último evento
/// puntual para mostrarlo durante [UmbralesAviso.duracionPuntual].
///
/// Avisan los eventos nuevos: uno puntual o el inicio de un exceso de
/// velocidad. Las actualizaciones y el cierre del exceso no avisan.
class GestorAvisos {
  EventoRiesgo? _puntual;
  DateTime? _puntualDesde;

  /// El último evento puntual y desde cuándo se muestra.
  EventoRiesgo? get puntual => _puntual;
  DateTime? get puntualDesde => _puntualDesde;

  /// [nuevo]: el viaje no lo tenía (no es la actualización de uno ya
  /// registrado). Devuelve si hay que vibrar y sonar.
  bool registrar(
    EventoRiesgo evento, {
    required bool nuevo,
    required DateTime ahora,
  }) {
    if (!nuevo) return false;
    if (evento.tipo != TipoEvento.excesoVelocidad) {
      // El más reciente reemplaza al anterior y vuelve a contar desde cero
      _puntual = evento;
      _puntualDesde = ahora;
    }
    return true;
  }

  void reiniciar() {
    _puntual = null;
    _puntualDesde = null;
  }
}

/// Lo que muestra el encabezado de la pantalla en vivo: un evento puntual
/// vigente tiene prioridad sobre el exceso de velocidad abierto.
sealed class AvisoEnVivo {
  const AvisoEnVivo();

  factory AvisoEnVivo.de({
    required List<EventoRiesgo> eventos,
    required DateTime ahora,
    EventoRiesgo? puntual,
    DateTime? puntualDesde,
  }) {
    if (puntual != null &&
        puntualDesde != null &&
        ahora.difference(puntualDesde) < UmbralesAviso.duracionPuntual) {
      return AvisoPuntual(puntual.tipo);
    }
    final exceso = eventos
        .where((e) => e.tipo == TipoEvento.excesoVelocidad && e.enCurso)
        .lastOrNull;
    if (exceso != null) return AvisoExceso(exceso.duracionS ?? 0);
    return const SinAviso();
  }
}

class AvisoPuntual extends AvisoEnVivo {
  const AvisoPuntual(this.tipo);

  final TipoEvento tipo;
}

class AvisoExceso extends AvisoEnVivo {
  const AvisoExceso(this.duracionS);

  /// Tiempo que lleva sobre el límite.
  final double duracionS;
}

class SinAviso extends AvisoEnVivo {
  const SinAviso();
}
