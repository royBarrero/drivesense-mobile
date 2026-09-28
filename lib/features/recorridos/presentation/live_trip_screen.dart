import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/trip_provider.dart';
import 'trip_format.dart';
import 'widgets/metric_tile.dart';

/// Viaje en curso: velocidad, tiempo y distancia en vivo (HU-04) y "Finalizar viaje" (HU-05).
///
/// "Atrás" vuelve a Inicio y el viaje sigue registrándose.
class RecorridoEnVivoPantalla extends ConsumerStatefulWidget {
  const RecorridoEnVivoPantalla({super.key});

  @override
  ConsumerState<RecorridoEnVivoPantalla> createState() =>
      _RecorridoEnVivoPantallaState();
}

class _RecorridoEnVivoPantallaState
    extends ConsumerState<RecorridoEnVivoPantalla> {
  bool _finalizando = false;
  String? _error;

  /// Último estado mostrado: se mantiene en pantalla mientras se finaliza.
  ViajeEnCurso? _ultimo;

  Future<void> _confirmarFinalizar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Finalizar el viaje?'),
        content: const Text('Se guardará el resumen de tu recorrido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Seguir registrando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() {
      _finalizando = true;
      _error = null;
    });
    try {
      await ref.read(viajeProvider.notifier).finalizar();
      if (mounted) context.go(Rutas.resumenRecorrido);
    } on ErrorRecorrido catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  void _volver() => context.canPop() ? context.pop() : context.go(Rutas.inicio);

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estado = ref.watch(viajeProvider).value;
    if (estado is ViajeEnCurso) _ultimo = estado;
    final viaje = _ultimo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos claros sobre el bloque oscuro
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: viaje == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BloqueVelocidad(viaje: viaje, alVolver: _volver),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(Espacios.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TarjetaMetrica(
                                    icono: Icons.timer_outlined,
                                    tinte: colores.tintePrimario,
                                    colorIcono: colores.primarioOscuro,
                                    etiqueta: 'Tiempo',
                                    valor: FormatoViaje.duracion(
                                      viaje.duracionS,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Espacios.m),
                                Expanded(
                                  child: TarjetaMetrica(
                                    icono: Icons.route_outlined,
                                    tinte: colores.tinteConfort,
                                    colorIcono: colores.confort,
                                    etiqueta: 'Distancia',
                                    valor: FormatoViaje.kilometros(
                                      viaje.distanciaM,
                                    ),
                                    unidad: 'km',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Espacios.m),
                            Container(
                              padding: const EdgeInsets.all(Espacios.s),
                              decoration: BoxDecoration(
                                color: colores.superficieAlt,
                                borderRadius: BorderRadius.circular(
                                  Radios.micro,
                                ),
                                border: Border.all(color: colores.borde),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.phonelink_lock_outlined,
                                    size: Medidas.icono,
                                    color: colores.primarioOscuro,
                                  ),
                                  const SizedBox(width: Espacios.xs),
                                  Expanded(
                                    child: Text(
                                      'Puedes apagar la pantalla: seguimos '
                                      'registrando tu viaje.',
                                      style: tipografia.cuerpoPequeno.copyWith(
                                        color: colores.textoSecundario,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (_error != null) ...[
                              AvisoError(mensaje: _error!),
                              const SizedBox(height: Espacios.m),
                            ],
                            BotonPrimario(
                              texto: 'Finalizar viaje',
                              icono: Icons.stop_rounded,
                              cargando: _finalizando,
                              alPresionar: _confirmarFinalizar,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bloque oscuro superior: estado, velocidad y máxima, con la diana detrás.
class _BloqueVelocidad extends StatelessWidget {
  const _BloqueVelocidad({required this.viaje, required this.alVolver});

  /// La ruta no cruza la velocidad ni "km/h" (el círculo intermedio de la diana).
  static const _huecoVelocidad = 50.0 * 1.9;

  final ViajeEnCurso viaje;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: Container(
        height: Medidas.altoBloqueEnVivo,
        color: colores.encabezadoFondo,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IlustracionRutaPainter(
                  colorLineas: colores.encabezadoBorde,
                  colorAcento: colores.encabezadoAcento,
                  // Centrada detrás de la velocidad
                  centro: (tamano) =>
                      Offset(tamano.width / 2, tamano.height * 0.56),
                  escala: 1.9,
                  conPunto: false,
                  huecoCentral: _huecoVelocidad,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacios.l,
                  Espacios.xs,
                  Espacios.l,
                  Espacios.l,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BotonVolver(alPresionar: alVolver),
                        Expanded(
                          child: Center(
                            child: _Capsula(
                              fondo: colores.acentoOscuroTenue,
                              color: colores.encabezadoAcento,
                              punto: true,
                              texto: 'Registrando viaje',
                            ),
                          ),
                        ),
                        viaje.sinSenal
                            ? _Capsula(
                                borde: colores.advertencia,
                                color: colores.advertencia,
                                icono: Icons.gps_not_fixed,
                                texto: 'Sin señal',
                              )
                            : _Capsula(
                                borde: colores.encabezadoBorde,
                                color: colores.encabezadoTextoSecundario,
                                icono: Icons.gps_fixed,
                                texto: 'GPS',
                              ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Etiqueta(
                              'Velocidad actual',
                              grande: true,
                              color: colores.encabezadoTextoSecundario,
                            ),
                            const SizedBox(height: Espacios.xs),
                            Text(
                              FormatoViaje.velocidad(viaje.velocidadKmh),
                              style: tipografia.velocimetro.copyWith(
                                color: colores.encabezadoTexto,
                              ),
                            ),
                            Text(
                              'km/h',
                              style: tipografia.subtitulo.copyWith(
                                color: colores.encabezadoTextoSecundario,
                              ),
                            ),
                            const SizedBox(height: Espacios.m),
                            _Capsula(
                              fondo: colores.encabezadoSuperficie,
                              borde: colores.encabezadoBorde,
                              color: colores.encabezadoTextoSecundario,
                              icono: Icons.speed,
                              texto:
                                  'Máxima ${FormatoViaje.velocidad(viaje.viaje.acumulador.velocidadMaximaKmh)} km/h',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonVolver extends StatelessWidget {
  const _BotonVolver({required this.alPresionar});

  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.encabezadoSuperficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.logo),
        side: BorderSide(color: colores.encabezadoBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: SizedBox.square(
          dimension: Medidas.botonVolver,
          child: Tooltip(
            message: 'Volver al inicio',
            child: Icon(
              Icons.arrow_back,
              size: Medidas.icono,
              color: colores.encabezadoTexto,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cápsula de estado sobre el bloque oscuro.
class _Capsula extends StatelessWidget {
  const _Capsula({
    required this.color,
    required this.texto,
    this.fondo,
    this.borde,
    this.icono,
    this.punto = false,
  });

  final Color color;
  final String texto;
  final Color? fondo;
  final Color? borde;
  final IconData? icono;

  /// Punto de color en lugar de ícono ("● Registrando viaje").
  final bool punto;

  static const _ladoPunto = 8.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Radios.pildora),
        border: borde == null ? null : Border.all(color: borde!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto)
            Container(
              width: _ladoPunto,
              height: _ladoPunto,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icono != null)
            Icon(icono, size: Medidas.iconoPequeno, color: color),
          const SizedBox(width: Espacios.xxs + 2),
          Text(
            texto,
            style: context.tipografia.cuerpoPequeno.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
