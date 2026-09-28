import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import 'trip_format.dart';
import 'widgets/metric_tile.dart';

/// Resumen del viaje recién finalizado (HU-05).
///
/// Guardado o pendiente de envío: bloque oscuro con las métricas superpuestas.
/// Descartado o rechazado: aviso centrado con lo que midió el intento.
class ResumenRecorridoPantalla extends ConsumerWidget {
  const ResumenRecorridoPantalla({super.key});

  void _salir(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(viajeProvider.notifier);
    context.go(Rutas.inicio);
    notifier.cerrarResumen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final estado = ref.watch(viajeProvider).value;
    if (estado is! ViajeTerminado) {
      return Scaffold(backgroundColor: colores.fondo);
    }

    final guardado =
        estado.resultado == ResultadoViaje.finalizado ||
        estado.resultado == ResultadoViaje.pendiente;
    final volver = BotonPrimario(
      texto: 'Volver al inicio',
      alPresionar: () => _salir(context, ref),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir(context, ref);
      },
      child: guardado
          ? _ResumenGuardado(estado: estado, boton: volver)
          : _ResumenNoGuardado(estado: estado, boton: volver),
    );
  }
}

/// Finalizado o pendiente de envío.
class _ResumenGuardado extends StatelessWidget {
  const _ResumenGuardado({required this.estado, required this.boton});

  final ViajeTerminado estado;
  final Widget boton;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final resumen = estado.resumen;
    final pendiente = estado.resultado == ResultadoViaje.pendiente;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(Radios.encabezado),
                        ),
                        child: Container(
                          // Sin ancho explícito, dentro del Stack se ajustaría al texto
                          width: double.infinity,
                          height: Medidas.altoBloqueResumen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Espacios.xl,
                          ),
                          color: colores.encabezadoFondo,
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: Medidas.circuloEstado,
                                  height: Medidas.circuloEstado,
                                  decoration: BoxDecoration(
                                    color: pendiente
                                        ? colores.advertencia
                                        : colores.encabezadoAcento,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    pendiente
                                        ? Icons.cloud_upload_outlined
                                        : Icons.check_rounded,
                                    size: Medidas.iconoEstado,
                                    color: colores.sobreAcentoOscuro,
                                  ),
                                ),
                                const SizedBox(height: Espacios.m),
                                Text(
                                  pendiente
                                      ? 'Viaje guardado en el teléfono'
                                      : 'Viaje guardado',
                                  textAlign: TextAlign.center,
                                  style: tipografia.tituloGrande.copyWith(
                                    color: colores.encabezadoTexto,
                                  ),
                                ),
                                const SizedBox(height: Espacios.xxs),
                                Text(
                                  FormatoViaje.franjaHoraria(
                                    resumen.fechaFin,
                                    resumen.duracionS,
                                  ),
                                  style: tipografia.cuerpo.copyWith(
                                    color: colores.encabezadoTextoSecundario,
                                  ),
                                ),
                                // Espacio que tapa la tarjeta superpuesta
                                const SizedBox(
                                  height: Medidas.superposicionResumen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Espacios.m,
                          Medidas.altoBloqueResumen -
                              Medidas.superposicionResumen,
                          Espacios.m,
                          0,
                        ),
                        child: _TarjetaMetricas(resumen: resumen),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espacios.l),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espacios.xl,
                    ),
                    child: Text(
                      pendiente
                          ? 'No hay conexión. Se enviará automáticamente '
                                'cuando vuelva.'
                          : 'Podrás revisar este viaje en tu historial.',
                      textAlign: TextAlign.center,
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Espacios.l),
                child: boton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grilla 2x2 con las métricas del viaje.
class _TarjetaMetricas extends StatelessWidget {
  const _TarjetaMetricas({required this.resumen});

  final ResumenRecorrido resumen;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjetaDestacada),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        children: [
          _Fila(
            izquierda: MetricaTintada(
              icono: Icons.route_outlined,
              tinte: colores.tinteConfort,
              colorIcono: colores.confort,
              etiqueta: 'Distancia',
              valor: FormatoViaje.kilometros(resumen.distanciaM),
              unidad: 'km',
            ),
            derecha: MetricaTintada(
              icono: Icons.timer_outlined,
              tinte: colores.tintePrimario,
              colorIcono: colores.primarioOscuro,
              etiqueta: 'Duración',
              valor: FormatoViaje.duracion(resumen.duracionS),
            ),
          ),
          const SizedBox(height: Espacios.s),
          _Fila(
            izquierda: MetricaTintada(
              icono: Icons.speed,
              tinte: colores.tinteAdvertencia,
              colorIcono: colores.advertencia,
              etiqueta: 'Vel. máxima',
              valor: FormatoViaje.velocidad(resumen.velocidadMaximaKmh),
              unidad: 'km/h',
            ),
            derecha: MetricaTintada(
              icono: Icons.av_timer,
              tinte: colores.tintePrimario,
              colorIcono: colores.primarioOscuro,
              etiqueta: 'Vel. promedio',
              valor: FormatoViaje.velocidad(resumen.velocidadPromedioKmh),
              unidad: 'km/h',
            ),
          ),
        ],
      ),
    );
  }
}

/// Descartado (muy corto) o rechazado por el backend.
class _ResumenNoGuardado extends StatelessWidget {
  const _ResumenNoGuardado({required this.estado, required this.boton});

  final ViajeTerminado estado;
  final Widget boton;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final resumen = estado.resumen;
    final descartado = estado.resultado == ResultadoViaje.descartado;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Espacios.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            width: Medidas.circuloDescartado,
                            height: Medidas.circuloDescartado,
                            decoration: BoxDecoration(
                              color: descartado
                                  ? colores.tinteAdvertencia
                                  : colores.tintePeligro,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              descartado
                                  ? Icons.timer_outlined
                                  : Icons.error_outline,
                              size: Medidas.iconoEstado,
                              color: descartado
                                  ? colores.advertencia
                                  : colores.textoPeligro,
                            ),
                          ),
                          const SizedBox(height: Espacios.xl),
                          Text(
                            descartado
                                ? 'El viaje fue muy corto y no se guardó'
                                : 'No se pudo guardar el viaje',
                            textAlign: TextAlign.center,
                            style: tipografia.titulo.copyWith(
                              color: colores.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: Espacios.s),
                          Text(
                            descartado
                                ? 'Guardamos los viajes de al menos 1 minuto y '
                                      '200 metros, para que tu historial refleje '
                                      'trayectos reales.'
                                : estado.mensaje ??
                                      'El servidor no aceptó el resumen del viaje.',
                            textAlign: TextAlign.center,
                            style: tipografia.cuerpo.copyWith(
                              color: colores.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: Espacios.xl),
                          _Fila(
                            izquierda: MetricaTintada(
                              icono: Icons.timer_outlined,
                              tinte: colores.superficie,
                              colorIcono: colores.primarioOscuro,
                              etiqueta: 'Duración',
                              valor: FormatoViaje.duracion(resumen.duracionS),
                            ),
                            derecha: MetricaTintada(
                              icono: Icons.route_outlined,
                              tinte: colores.superficie,
                              colorIcono: colores.confort,
                              etiqueta: 'Distancia',
                              valor: FormatoViaje.kilometros(
                                resumen.distanciaM,
                              ),
                              unidad: 'km',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                boton,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: izquierda),
          const SizedBox(width: Espacios.s),
          Expanded(child: derecha),
        ],
      ),
    );
  }
}
