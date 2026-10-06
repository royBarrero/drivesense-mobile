import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../../recorridos/providers/trip_provider.dart';
import '../../data/calibration_recorder.dart';
import '../../data/sensor_service.dart';
import '../../models/calibration_mark.dart';
import '../../models/sensor_sample.dart';
import '../../models/signal_filter.dart';

/// Panel de diagnóstico de la pantalla en vivo (solo en la versión de desarrollo):
/// frecuencia real y valores actuales de cada sensor, GPS, ruta, la señal
/// filtrada (HU-09) y, si se graba el CSV de calibración, las maniobras
/// marcadas de cada tipo. Los eventos detectados están en la tarjeta de
/// contadores (HU-14).
///
/// Se redibuja con cada estado del viaje (al menos una vez por segundo).
class PanelDiagnostico extends ConsumerWidget {
  const PanelDiagnostico({super.key, required this.viaje});

  final ViajeEnCurso viaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final sensores = ref.watch(capturaSensoresProvider);
    final registro = ref.watch(registroCalibracionProvider);
    final grabando = registro.grabando;
    final gps = viaje.lecturaGps;
    final sinGiroscopio = viaje.viaje.sinGiroscopio || sensores.sinGiroscopio;

    return Container(
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: colores.superficieAlt,
        borderRadius: BorderRadius.circular(Radios.micro),
        border: Border.all(color: colores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Etiqueta('Diagnóstico')),
              if (grabando)
                _Texto('● Grabando CSV', color: colores.textoPeligro),
            ],
          ),
          const SizedBox(height: Espacios.xxs),
          _FilaSensor(
            nombre: 'Acel.',
            hz: sensores.frecuenciaHz(TipoSensor.acelerometro, viaje.ahora),
            hzSensor: sensores.frecuenciaHz(
              TipoSensor.acelerometro,
              viaje.ahora,
              crudo: true,
            ),
            muestra: sensores.acelerometro.ultima,
          ),
          sinGiroscopio
              ? _Texto(
                  'Giro.  No disponible: sin detección de giros',
                  color: colores.advertencia,
                )
              : _FilaSensor(
                  nombre: 'Giro.',
                  hz: sensores.frecuenciaHz(TipoSensor.giroscopio, viaje.ahora),
                  hzSensor: sensores.frecuenciaHz(
                    TipoSensor.giroscopio,
                    viaje.ahora,
                    crudo: true,
                  ),
                  muestra: sensores.giroscopio.ultima,
                ),
          _Texto(
            'GPS    ${gps == null ? '—' : '±${gps.precisionM.toStringAsFixed(0)} m'}'
            '  ·  ruta ${viaje.viaje.ruta.cantidad} pts',
          ),
          _LineaFiltro(filtro: sensores.filtro),
          if (grabando)
            // "Marcas Fren. 2 · Giro 1 · Bache 0 · Tel. 1"
            _Texto(
              'Marcas ${TipoMarca.values.map((tipo) => '${tipo.abreviatura} ${registro.marcas(tipo)}').join(' · ')}',
            ),
        ],
      ),
    );
  }
}

/// Señal filtrada (HU-09): lo que recibirán los detectores.
class _LineaFiltro extends StatelessWidget {
  const _LineaFiltro({required this.filtro});

  final FiltroSenal filtro;

  @override
  Widget build(BuildContext context) {
    final velocidad = filtro.velocidades.lastOrNull;
    final giro = filtro.giroRadS;
    final descarte = filtro.descarte;
    // "Filtro 32.4 km/h · giro 0.12 rad/s · OK"
    return _Texto(
      'Filtro ${velocidad == null ? '—' : '${velocidad.velocidadKmh.toStringAsFixed(1)} km/h'}'
      '  ·  giro ${giro == null ? '—' : giro.toStringAsFixed(2)}'
      '  ·  ${descarte == null ? 'OK' : 'descartado: ${descarte.texto}'}',
      color: descarte == null ? null : context.colores.advertencia,
    );
  }
}

class _FilaSensor extends StatelessWidget {
  const _FilaSensor({
    required this.nombre,
    required this.hz,
    required this.hzSensor,
    required this.muestra,
  });

  final String nombre;

  /// Frecuencia del búfer (~50 Hz) y la que entrega el sensor.
  final double hz;
  final double hzSensor;
  final MuestraSensor? muestra;

  static String _eje(double valor) => valor.toStringAsFixed(2).padLeft(6);

  @override
  Widget build(BuildContext context) {
    final m = muestra;
    final valores = m == null
        ? '—'
        : 'x${_eje(m.x)} y${_eje(m.y)} z${_eje(m.z)}';
    // "50.0 Hz (125)": en el búfer y, entre paréntesis, lo que entrega el sensor
    return _Texto(
      '${nombre.padRight(6)} ${hz.toStringAsFixed(1).padLeft(4)} Hz '
      '(${hzSensor.toStringAsFixed(0)})  $valores',
    );
  }
}

class _Texto extends StatelessWidget {
  const _Texto(this.texto, {this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.tipografia.ayuda.copyWith(
        color: color ?? context.colores.textoSecundario,
        // Cifras de ancho fijo: los valores no bailan al cambiar
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
