import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/trip.dart';
import '../models/trip_accumulator.dart';
import '../models/trip_score.dart';
import '../providers/trip_provider.dart';
import 'trip_format.dart';
import 'trip_map_screen.dart';
import 'widgets/drive_score_ring.dart';
import 'widgets/event_counts_row.dart';
import 'widgets/map_button.dart';
import 'widgets/metric_tile.dart';
import 'widgets/score_breakdown.dart';
import 'widgets/trip_figures_row.dart';
import 'widgets/trip_map.dart';

/// Resumen del viaje recién finalizado (HU-05) con su DriveScore (HU-15) y el
/// mapa de la ruta con sus eventos (HU-29).
///
/// Guardado o pendiente de envío: bloque oscuro, tarjeta del mapa, DriveScore
/// y cifras.
/// Descartado o rechazado: aviso centrado con lo que midió el intento.
class ResumenRecorridoPantalla extends ConsumerWidget {
  const ResumenRecorridoPantalla({super.key});

  void _salir(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(viajeProvider.notifier);
    context.go(Rutas.inicio);
    notifier.cerrarResumen();
  }

  /// Abre el viaje recién guardado en el historial; "atrás" vuelve a la lista.
  void _verEnHistorial(BuildContext context, WidgetRef ref, int recorridoId) {
    final notifier = ref.read(viajeProvider.notifier);
    context.go(Rutas.detalleViaje(recorridoId));
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
    final volverAlInicio = BotonPrimario(
      texto: 'Volver al inicio',
      alPresionar: () => _salir(context, ref),
    );
    // Modo calibración (solo en desarrollo): el CSV del viaje
    final csv = estado.archivoCalibracion;
    final volver = csv == null
        ? volverAlInicio
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(csv, mimeType: 'text/csv')]),
                ),
                icon: const Icon(Icons.share_outlined, size: Medidas.icono),
                label: const Text('Compartir datos de calibración'),
              ),
              const SizedBox(height: Espacios.s),
              volverAlInicio,
            ],
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir(context, ref);
      },
      child: guardado
          ? _ResumenGuardado(
              estado: estado,
              boton: volver,
              // Pendiente de envío: el viaje aún no está en el historial
              alVerEnHistorial: estado.resultado == ResultadoViaje.finalizado
                  ? () => _verEnHistorial(
                      context,
                      ref,
                      estado.resumen.recorridoId,
                    )
                  : null,
            )
          : _ResumenNoGuardado(estado: estado, boton: volver),
    );
  }
}

/// Finalizado o pendiente de envío (HU-29, diseño 1): bloque oscuro con
/// "Viaje guardado"; encima, la tarjeta del mapa con los eventos; debajo, el
/// DriveScore (abre el detalle) y las cifras del viaje.
class _ResumenGuardado extends StatelessWidget {
  const _ResumenGuardado({
    required this.estado,
    required this.boton,
    required this.alVerEnHistorial,
  });

  final ViajeTerminado estado;
  final Widget boton;
  final VoidCallback? alVerEnHistorial;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final resumen = estado.resumen;
    final pendiente = estado.resultado == ResultadoViaje.pendiente;
    final margenSuperior = MediaQuery.paddingOf(context).top;
    final conTarjetaMapa =
        DatosMapaViaje.hayRuta(resumen.ruta) || resumen.eventos != null;

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
                      _EncabezadoGuardado(
                        alto: margenSuperior + Medidas.altoEncabezadoResumen,
                        pendiente: pendiente,
                        franja: FormatoViaje.franjaHoraria(
                          resumen.fechaFin,
                          resumen.duracionS,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Espacios.m,
                          margenSuperior +
                              Medidas.altoEncabezadoResumen +
                              (conTarjetaMapa
                                  ? -Medidas.superposicionMapaResumen
                                  : Espacios.l),
                          Espacios.m,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (conTarjetaMapa) ...[
                              _TarjetaMapa(resumen: resumen),
                              const SizedBox(height: Espacios.m),
                            ],
                            _TarjetaDriveScore(
                              puntaje: estado.puntaje,
                              pendiente: pendiente,
                              // Un pendiente de una versión anterior no trae
                              // eventos
                              sinEventos: resumen.eventos?.isEmpty ?? false,
                              alPresionar: alVerEnHistorial,
                            ),
                            const SizedBox(height: Espacios.m),
                            FilaCifras(
                              distanciaM: resumen.distanciaM,
                              duracionS: resumen.duracionS,
                              velocidadMaximaKmh: resumen.velocidadMaximaKmh,
                              velocidadPromedioKmh:
                                  resumen.velocidadPromedioKmh,
                            ),
                            if (estado.automatico) ...[
                              const SizedBox(height: Espacios.m),
                              const _AvisoAutomatico(),
                            ],
                            if (pendiente) ...[
                              const SizedBox(height: Espacios.l),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Espacios.s,
                                ),
                                child: Text(
                                  'No hay conexión. Se enviará '
                                  'automáticamente cuando vuelva.',
                                  textAlign: TextAlign.center,
                                  style: tipografia.cuerpoPequeno.copyWith(
                                    color: colores.textoSecundario,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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

/// Bloque oscuro: círculo con el check (o el teléfono, pendiente de envío),
/// "Viaje guardado" y la franja horaria.
class _EncabezadoGuardado extends StatelessWidget {
  const _EncabezadoGuardado({
    required this.alto,
    required this.pendiente,
    required this.franja,
  });

  final double alto;
  final bool pendiente;
  final String franja;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: Container(
        height: alto,
        color: colores.encabezadoFondo,
        child: CustomPaint(
          painter: IlustracionRutaPainter(
            colorLineas: colores.encabezadoBorde,
            colorAcento: colores.acentoOscuroTenue,
            centro: (tamano) => Offset(tamano.width - 40, tamano.height * 0.3),
            escala: 1.6,
            conPunto: false,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espacios.l,
                Espacios.l,
                Espacios.l,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: Medidas.circuloCheckResumen,
                    height: Medidas.circuloCheckResumen,
                    decoration: BoxDecoration(
                      color: colores.encabezadoAcento,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colores.acentoOscuroTenue,
                        width: Espacios.xs,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                    child: Icon(
                      pendiente
                          ? Icons.phone_android_rounded
                          : Icons.check_rounded,
                      size: Medidas.iconoEstado,
                      color: colores.sobreAcentoOscuro,
                    ),
                  ),
                  const SizedBox(width: Espacios.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Viaje guardado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tipografia.tituloGrande.copyWith(
                            color: colores.encabezadoTexto,
                          ),
                        ),
                        const SizedBox(height: Espacios.xxs),
                        Text(
                          // Aún sin enviar: solo está en el teléfono
                          pendiente ? 'En el teléfono · $franja' : franja,
                          style: tipografia.cuerpo.copyWith(
                            color: colores.encabezadoTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del mapa (HU-29): la ruta con los eventos (o el aviso sin
/// conexión), los contadores por tipo y "Ver mapa completo". Sin ruta, solo
/// los contadores; sin eventos (pendiente de una versión anterior), solo el
/// mapa.
class _TarjetaMapa extends StatefulWidget {
  const _TarjetaMapa({required this.resumen});

  final ResumenRecorrido resumen;

  @override
  State<_TarjetaMapa> createState() => _TarjetaMapaState();
}

class _TarjetaMapaState extends State<_TarjetaMapa> {
  /// Cargan los mosaicos (falso: aviso sin conexión).
  bool _disponible = true;

  void _abrirMapa() {
    final resumen = widget.resumen;
    context.push(
      Rutas.mapaViaje,
      extra: DatosMapaViaje(
        ruta: resumen.ruta!,
        eventos: resumen.eventos ?? const [],
        llegada: resumen.fechaFin,
        duracionS: resumen.duracionS,
        distanciaM: resumen.distanciaM,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final resumen = widget.resumen;
    final eventos = resumen.eventos;
    final ruta = resumen.ruta;
    final conMapa = DatosMapaViaje.hayRuta(ruta);

    return Container(
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (conMapa)
            ClipRRect(
              borderRadius: BorderRadius.circular(Radios.micro),
              child: SizedBox(
                height: Medidas.altoMapaResumen,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MapaViaje(
                        ruta: ruta!,
                        eventos: eventos ?? const [],
                        alTocar: _abrirMapa,
                        alCambiarDisponibilidad: (disponible) =>
                            setState(() => _disponible = disponible),
                      ),
                    ),
                    if (_disponible) ...[
                      if (eventos != null)
                        Positioned(
                          left: Espacios.s,
                          top: Espacios.s,
                          child: _CapsulaEventos(cantidad: eventos.length),
                        ),
                      Positioned(
                        right: Espacios.s,
                        top: Espacios.s,
                        child: BotonMapa(
                          icono: Icons.open_in_full_rounded,
                          descripcion: 'Ver mapa completo',
                          alPresionar: _abrirMapa,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (eventos != null) ...[
            if (conMapa) const SizedBox(height: Espacios.m),
            FilaConteoEventos(conteo: FilaConteoEventos.contar(eventos)),
          ],
          if (conMapa && _disponible) ...[
            const SizedBox(height: Espacios.m),
            Material(
              color: colores.superficieAlt,
              borderRadius: BorderRadius.circular(Radios.micro),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radios.micro),
                onTap: _abrirMapa,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espacios.s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ver mapa completo',
                        style: tipografia.subtitulo.copyWith(
                          color: colores.enlace,
                        ),
                      ),
                      const SizedBox(width: Espacios.xxs),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: Medidas.icono,
                        color: colores.enlace,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "5 eventos" sobre el mapa.
class _CapsulaEventos extends StatelessWidget {
  const _CapsulaEventos({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.xxs,
      ),
      decoration: BoxDecoration(
        color: colores.encabezadoFondo,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Text(
        switch (cantidad) {
          0 => 'Sin eventos',
          1 => '1 evento',
          _ => '$cantidad eventos',
        },
        style: context.tipografia.cuerpo.copyWith(
          fontWeight: FontWeight.w700,
          color: colores.encabezadoTexto,
        ),
      ),
    );
  }
}

/// DriveScore del viaje con la calificación y "Lo que más restó" (HU-15,
/// HU-16); la flecha abre el detalle, con el desglose. Mientras el envío está
/// pendiente, aviso de que se calculará después.
class _TarjetaDriveScore extends StatelessWidget {
  const _TarjetaDriveScore({
    required this.puntaje,
    required this.pendiente,
    required this.sinEventos,
    required this.alPresionar,
  });

  final PuntajeViaje? puntaje;
  final bool pendiente;
  final bool sinEventos;

  /// Nulo si el viaje aún no está en el historial.
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final puntaje = this.puntaje;
    final (titulo, color, detalle) = switch (puntaje?.calificacion) {
      null when pendiente => (
        'Calculando tu DriveScore',
        colores.textoPrincipal,
        'Se calculará cuando se envíe el viaje.',
      ),
      null => ('DriveScore no disponible', colores.textoPrincipal, null),
      final calificacion => (
        calificacion.texto,
        colorCalificacion(calificacion, colores),
        textoMasResto(puntaje!, sinEventos: sinEventos),
      ),
    };
    final alPresionar = this.alPresionar;

    return Material(
      color: colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        side: BorderSide(color: colores.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(Espacios.m),
          child: Row(
            children: [
              AnilloDriveScore.claro(
                puntaje: puntaje?.drivescore,
                esperando: pendiente,
              ),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Etiqueta('DriveScore del viaje'),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      titulo,
                      style: tipografia.tituloTarjeta.copyWith(color: color),
                    ),
                    if (detalle != null) ...[
                      const SizedBox(height: Espacios.xxs),
                      Text(
                        detalle,
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (alPresionar != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: Medidas.iconoNavegacion,
                  color: colores.textoSecundario,
                ),
            ],
          ),
        ),
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
                          if (estado.automatico) ...[
                            const SizedBox(height: Espacios.l),
                            const _AvisoAutomatico(),
                          ],
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

/// El viaje lo finalizó la app porque el auto quedó detenido.
class _AvisoAutomatico extends StatelessWidget {
  const _AvisoAutomatico();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final minutos = UmbralesRecorrido.detenidoParaFinalizar.inMinutes;
    return Container(
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: colores.tinteAdvertencia,
        borderRadius: BorderRadius.circular(Radios.campo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_parking_rounded,
            size: Medidas.icono,
            color: colores.advertencia,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              'Lo finalizamos automáticamente: estuviste detenido $minutos '
              'min. El viaje termina donde te detuviste.',
              style: context.tipografia.cuerpoPequeno.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
