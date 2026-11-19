/// Qué dice el Copiloto por voz y cuándo (HU-31). Dart puro.
library;

import 'route_plan.dart';
import 'route_progress.dart';

/// Frases fijas del Copiloto (en el CLAUDE.md).
abstract final class FrasesCopiloto {
  static const desvio = 'Te saliste de la ruta. Recalculando.';
  static const rutaActualizada = 'Ruta actualizada.';
  static const sinConexionRecalcular =
      'Sin conexión: sigo con la última ruta, no puedo recalcular.';
  static const sinRutaAlContinuar =
      'No pude calcular la ruta. El viaje se sigue registrando.';
  static const llegada = 'Llegaste a tu destino.';
}

/// Umbral de aviso de una maniobra.
enum AvisoManiobra { lejos, cerca, ahora }

/// Decide los avisos de maniobra y de llegada: cada umbral se dice una sola
/// vez por maniobra. Al cambiar de ruta (recálculo) se empieza de nuevo.
class GuiaVoz {
  final _dichos = <int, Set<AvisoManiobra>>{};
  bool _llegadaDicha = false;

  bool get llegadaDicha => _llegadaDicha;

  /// Ruta nueva: los avisos dichos ya no corresponden a sus pasos.
  void nuevaRuta() {
    _dichos.clear();
  }

  /// Lo que hay que decir con este [progreso] (como indicación de ruta, con
  /// prioridad), o `null`. [seguidor] da el largo del tramo de cada paso.
  String? evaluar(ProgresoRuta progreso, SeguidorRuta seguidor) {
    if (_llegadaDicha) return null;
    if (progreso.llego) {
      _llegadaDicha = true;
      return FrasesCopiloto.llegada;
    }
    final proxima = progreso.proxima;
    final indice = progreso.indiceProxima;
    if (proxima == null || indice == null) return null;
    // La salida es el punto de partida: no se anuncia
    if (proxima.tipo == TipoPaso.salida) return null;

    final distancia = progreso.hastaProximaM;
    final dichos = _dichos.putIfAbsent(indice, () => {});
    final AvisoManiobra aviso;
    if (distancia <= UmbralesCopiloto.avisoAhoraM) {
      aviso = AvisoManiobra.ahora;
    } else if (distancia <= UmbralesCopiloto.avisoCercaM) {
      aviso = AvisoManiobra.cerca;
    } else if (distancia <= UmbralesCopiloto.avisoLejosM &&
        _tramo(indice, seguidor) > UmbralesCopiloto.tramoLargoM) {
      aviso = AvisoManiobra.lejos;
    } else {
      return null;
    }
    if (dichos.contains(aviso)) return null;
    // Un aviso más cercano deja sin sentido los más lejanos
    dichos.addAll(AvisoManiobra.values.where((a) => a.index <= aviso.index));
    return frase(proxima, aviso == AvisoManiobra.ahora ? null : distancia);
  }

  /// Largo del tramo que lleva a la maniobra [indice] (desde la anterior).
  static double _tramo(int indice, SeguidorRuta seguidor) {
    final pasos = seguidor.ruta.pasos;
    final desde = indice == 0 ? 0 : pasos[indice - 1].inicio;
    return seguidor.acumuladoEn(pasos[indice].inicio) -
        seguidor.acumuladoEn(desde);
  }

  /// "En 100 metros, gira a la derecha en Avenida Busch" o, sin [distanciaM],
  /// "Ahora, gira a la derecha en Avenida Busch".
  static String frase(PasoRuta paso, double? distanciaM) {
    final accion = maniobra(paso);
    final cuando = distanciaM == null
        ? 'Ahora'
        : 'En ${metrosHablados(distanciaM)}';
    return '$cuando, $accion.';
  }

  /// Distancia redondeada como se dice: "100 metros", "300 metros",
  /// "1,5 kilómetros". Bajo 100, a la decena; desde ahí, a la cincuentena.
  static String metrosHablados(double metros) {
    if (metros >= 1000) {
      final km = (metros / 100).round() / 10;
      final texto = km == km.roundToDouble()
          ? km.toStringAsFixed(0)
          : km.toStringAsFixed(1).replaceAll('.', ',');
      return '$texto kilómetro${km == 1 ? '' : 's'}';
    }
    final redondeo = metros < 100 ? 10 : 50;
    final valor = ((metros / redondeo).round() * redondeo).clamp(10, 950);
    return '$valor metros';
  }

  /// La acción en tuteo, con la calle si la hay: "gira a la derecha en
  /// Avenida Busch", "en la rotonda, toma la segunda salida".
  static String maniobra(PasoRuta paso) {
    final calle = paso.calle;
    final enCalle = calle == null ? '' : ' en $calle';
    final porCalle = calle == null ? '' : ' por $calle';
    return switch (paso.tipo) {
      TipoPaso.girarIzquierda => 'gira a la izquierda$enCalle',
      TipoPaso.girarDerecha => 'gira a la derecha$enCalle',
      TipoPaso.girarFuerteIzquierda => 'gira cerrado a la izquierda$enCalle',
      TipoPaso.girarFuerteDerecha => 'gira cerrado a la derecha$enCalle',
      TipoPaso.girarLeveIzquierda => 'gira levemente a la izquierda$enCalle',
      TipoPaso.girarLeveDerecha => 'gira levemente a la derecha$enCalle',
      TipoPaso.seguirRecto => 'sigue derecho$porCalle',
      TipoPaso.entrarRotonda => switch (paso.salidaRotonda) {
        final salida? => 'en la rotonda, toma la ${_ordinal(salida)} salida',
        null => 'entra a la rotonda',
      },
      TipoPaso.salirRotonda => 'sal de la rotonda$porCalle',
      TipoPaso.mediaVuelta => 'da media vuelta',
      TipoPaso.llegada => 'llegas a tu destino',
      TipoPaso.salida => 'sal$porCalle',
      TipoPaso.mantenerIzquierda => 'mantente a la izquierda$porCalle',
      TipoPaso.mantenerDerecha => 'mantente a la derecha$porCalle',
    };
  }

  /// Texto corto de la maniobra para la pantalla: "Gira a la derecha".
  static String titulo(PasoRuta paso) {
    final sinCalle = PasoRuta(
      instruccion: paso.instruccion,
      tipo: paso.tipo,
      distanciaM: paso.distanciaM,
      duracionS: paso.duracionS,
      salidaRotonda: paso.salidaRotonda,
    );
    final texto = maniobra(sinCalle);
    return texto[0].toUpperCase() + texto.substring(1);
  }

  static const _ordinales = [
    'primera',
    'segunda',
    'tercera',
    'cuarta',
    'quinta',
    'sexta',
    'séptima',
    'octava',
    'novena',
    'décima',
  ];

  static String _ordinal(int n) =>
      n >= 1 && n <= _ordinales.length ? _ordinales[n - 1] : '$n.ª';
}
