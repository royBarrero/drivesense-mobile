import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/label.dart';
import '../models/trip_history.dart';
import '../providers/trip_history_provider.dart';
import 'trip_format.dart';
import 'widgets/load_error.dart';
import '../../telemetria/models/event_detector.dart';
import '../models/trip_score.dart';
import '../../telemetria/models/route.dart';
import 'trip_map_screen.dart';
import 'widgets/drive_score_ring.dart';
import 'widgets/event_counts_row.dart';
import 'widgets/map_button.dart';
import 'widgets/score_breakdown.dart';
import 'widgets/trip_figures_row.dart';
import 'widgets/trip_map.dart';

/// Detalle de un viaje del historial (HU-06): el mapa de la ruta con sus
/// eventos (HU-29; sin ruta, la cabecera con el degradado), fecha y horas, los
/// eventos por tipo, el DriveScore con su desglose (HU-16) y las cifras.
class DetalleViajePantalla extends ConsumerWidget {
  const DetalleViajePantalla({super.key, required this.recorridoId});

  final int recorridoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final detalle = ref.watch(detalleRecorridoProvider(recorridoId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.fondo,
        body: switch (detalle) {
          AsyncValue(:final value?) => _Contenido(recorrido: value),
          AsyncValue(:final error?) when !detalle.isLoading => SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(Espacios.l),
                  child: _BotonVolver(),
                ),
                Expanded(
                  child: Center(
                    child: ErrorCarga(
                      error: error,
                      alReintentar: () =>
                          ref.invalidate(detalleRecorridoProvider(recorridoId)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.recorrido});

  final RecorridoHistorial recorrido;

  @override
  Widget build(BuildContext context) {
    final ruta = recorrido.ruta;
    final eventosPorTipo = recorrido.eventosPorTipo;
    final altoMapa =
        MediaQuery.paddingOf(context).top + Medidas.altoMapaDetalle;
    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + Espacios.l,
      ),
      children: [
        // Con ruta (HU-29), el mapa en lugar del degradado
        if (DatosMapaViaje.hayRuta(ruta))
          Stack(
            children: [
              _CabeceraMapa(recorrido: recorrido, ruta: ruta!, alto: altoMapa),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Espacios.m,
                  altoMapa - Medidas.superposicionDetalle,
                  Espacios.m,
                  0,
                ),
                child: _TarjetaFechaHoras(recorrido: recorrido),
              ),
            ],
          )
        else
          Stack(
            children: [
              _Cabecera(recorrido: recorrido),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacios.m,
                  Medidas.altoCabeceraDetalle - Medidas.superposicionDetalle,
                  Espacios.m,
                  0,
                ),
                child: _TarjetaSalidaLlegada(recorrido: recorrido),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espacios.m,
            Espacios.m,
            Espacios.m,
            0,
          ),
          child: Column(
            children: [
              if (eventosPorTipo != null) ...[
                _Tarjeta(child: FilaConteoEventos(conteo: eventosPorTipo)),
                const SizedBox(height: Espacios.m),
              ],
              // Sin DriveScore (viajes de antes de HU-15): solo las cifras
              if (recorrido.puntaje case final puntaje?) ...[
                _TarjetaDriveScore(
                  puntaje: puntaje,
                  eventosPorTipo: recorrido.eventosPorTipo,
                ),
                const SizedBox(height: Espacios.m),
              ],
              FilaCifras(
                distanciaM: recorrido.distanciaM,
                duracionS: recorrido.duracionS,
                velocidadMaximaKmh: recorrido.velocidadMaximaKmh,
                velocidadPromedioKmh: recorrido.velocidadPromedioKmh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// DriveScore del viaje (HU-16, diseño D): anillo pequeño, calificación, "Lo
/// que más restó" y el desglose por categoría con sus eventos.
class _TarjetaDriveScore extends StatelessWidget {
  const _TarjetaDriveScore({
    required this.puntaje,
    required this.eventosPorTipo,
  });

  final PuntajeViaje puntaje;
  final Map<TipoEvento, int>? eventosPorTipo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final masResto = textoMasResto(
      puntaje,
      sinEventos: eventosPorTipo?.values.every((n) => n == 0) ?? false,
    );

    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnilloDriveScore.claro(puntaje: puntaje.drivescore),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Etiqueta('DriveScore'),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      puntaje.calificacion.texto,
                      style: tipografia.tituloTarjeta.copyWith(
                        color: colorCalificacion(puntaje.calificacion, colores),
                      ),
                    ),
                    if (masResto != null) ...[
                      const SizedBox(height: Espacios.xxs),
                      Text(
                        masResto,
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.l),
          // Los eventos de cada tipo ya están en la tarjeta de contadores
          DesgloseCategorias(puntaje: puntaje),
        ],
      ),
    );
  }
}

/// Tarjeta grande blanca.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: child,
    );
  }
}

/// Cabecera con el mapa del viaje (HU-29, diseño 3): volver, "Detalle del
/// viaje" y expandir sobre el mapa; tocarlo abre el mapa completo.
class _CabeceraMapa extends StatefulWidget {
  const _CabeceraMapa({
    required this.recorrido,
    required this.ruta,
    required this.alto,
  });

  final RecorridoHistorial recorrido;
  final List<PuntoRuta> ruta;
  final double alto;

  @override
  State<_CabeceraMapa> createState() => _CabeceraMapaState();
}

class _CabeceraMapaState extends State<_CabeceraMapa> {
  /// Cargan los mosaicos (falso: aviso sin conexión).
  bool _disponible = true;

  void _abrirMapa() {
    final recorrido = widget.recorrido;
    context.push(
      Rutas.mapaViaje,
      extra: DatosMapaViaje(
        ruta: widget.ruta,
        eventos: recorrido.eventos ?? const [],
        llegada: recorrido.llegada,
        duracionS: recorrido.duracionS,
        distanciaM: recorrido.distanciaM,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final margenSuperior = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: widget.alto,
      child: Stack(
        children: [
          Positioned.fill(
            child: MapaViaje(
              ruta: widget.ruta,
              eventos: widget.recorrido.eventos ?? const [],
              alTocar: _abrirMapa,
              alCambiarDisponibilidad: (disponible) =>
                  setState(() => _disponible = disponible),
              relleno: EdgeInsets.only(
                top: margenSuperior + Espacios.s + Medidas.botonVolver,
                bottom: Medidas.superposicionDetalle,
              ),
            ),
          ),
          Positioned(
            left: Espacios.m,
            right: Espacios.m,
            top: margenSuperior + Espacios.s,
            child: Row(
              children: [
                BotonMapa(
                  icono: Icons.chevron_left_rounded,
                  descripcion: 'Volver',
                  circular: true,
                  alPresionar: () => context.canPop()
                      ? context.pop()
                      : context.go(Rutas.viajes),
                ),
                const SizedBox(width: Espacios.xs),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espacios.m,
                        vertical: Espacios.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colores.superficie,
                        borderRadius: BorderRadius.circular(Radios.pildora),
                        boxShadow: colores.sombraTarjeta,
                      ),
                      child: Text(
                        'Detalle del viaje',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tipografia.subtitulo.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Espacios.xs),
                if (_disponible)
                  BotonMapa(
                    icono: Icons.open_in_full_rounded,
                    descripcion: 'Ver mapa completo',
                    alPresionar: _abrirMapa,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fecha, salida → llegada y la distancia en grande, sobre el borde del mapa.
class _TarjetaFechaHoras extends StatelessWidget {
  const _TarjetaFechaHoras({required this.recorrido});

  final RecorridoHistorial recorrido;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final hora = tipografia.numeroMetrica.copyWith(
      fontWeight: FontWeight.w700,
      color: colores.textoPrincipal,
    );
    Widget punto({required bool lleno}) => Container(
      width: Medidas.puntoRecorrido,
      height: Medidas.puntoRecorrido,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lleno ? colores.textoPrincipal : null,
        border: lleno ? null : Border.all(color: colores.primario, width: 3),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.m,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjetaDestacada),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FormatoViaje.fechaDetalle(recorrido.salida),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
                const SizedBox(height: Espacios.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      punto(lleno: false),
                      const SizedBox(width: Espacios.xs),
                      Text(FormatoViaje.hora(recorrido.salida), style: hora),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Espacios.xs,
                        ),
                        child: Icon(
                          Icons.arrow_right_alt_rounded,
                          size: Medidas.icono,
                          color: colores.textoTerciario,
                        ),
                      ),
                      punto(lleno: true),
                      const SizedBox(width: Espacios.xs),
                      Text(FormatoViaje.hora(recorrido.llegada), style: hora),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espacios.s),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: FormatoViaje.kilometros(recorrido.distanciaM)),
                TextSpan(
                  text: ' km',
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
              ],
            ),
            style: tipografia.numeroGrande.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque con el degradado del DriveScore (viajes sin ruta): volver, fecha y
/// distancia en grande.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.recorrido});

  final RecorridoHistorial recorrido;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final texto = colores.textoSobreGradiente;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: Container(
        width: double.infinity,
        height: Medidas.altoCabeceraDetalle,
        decoration: BoxDecoration(gradient: colores.gradienteScore),
        child: CustomPaint(
          painter: IlustracionRutaPainter(
            colorLineas: colores.lineasSobreGradiente,
            colorAcento: colores.lineasSobreGradiente,
            centro: (tamano) => Offset(tamano.width - 40, tamano.height * 0.45),
            escala: 1.4,
            conPunto: false,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Espacios.s),
                  Row(
                    children: [
                      const _BotonVolver(),
                      const SizedBox(width: Espacios.m),
                      Text(
                        'Detalle del viaje',
                        style: tipografia.subtituloGrande.copyWith(
                          color: texto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espacios.l),
                  Text(
                    FormatoViaje.fechaDetalle(recorrido.salida),
                    style: tipografia.subtitulo.copyWith(color: texto),
                  ),
                  const SizedBox(height: Espacios.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: FormatoViaje.kilometros(recorrido.distanciaM),
                          ),
                          TextSpan(
                            text: ' km',
                            style: tipografia.subtituloGrande,
                          ),
                        ],
                      ),
                      style: tipografia.telemetriaXL.copyWith(color: texto),
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

/// Botón volver en caja de 44; sin pantalla anterior (p. ej. desde el resumen
/// con `go`) vuelve a la lista.
class _BotonVolver extends StatelessWidget {
  const _BotonVolver();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.superficieSobreGradiente,
      borderRadius: BorderRadius.circular(Radios.campo),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.campo),
        onTap: () =>
            context.canPop() ? context.pop() : context.go(Rutas.viajes),
        child: SizedBox.square(
          dimension: Medidas.botonVolver,
          child: Icon(
            Icons.chevron_left_rounded,
            size: Medidas.iconoNavegacion,
            color: colores.textoSobreGradiente,
          ),
        ),
      ),
    );
  }
}

/// Salida y llegada unidas por una línea punteada.
class _TarjetaSalidaLlegada extends StatelessWidget {
  const _TarjetaSalidaLlegada({required this.recorrido});

  final RecorridoHistorial recorrido;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final colorLlegada = colores.gradienteScore.colors.last;

    Widget fila(Widget marca, String texto, DateTime hora) => Row(
      children: [
        SizedBox.square(
          dimension: Medidas.icono,
          child: Center(child: marca),
        ),
        const SizedBox(width: Espacios.m),
        Expanded(
          child: Text(
            texto,
            style: tipografia.subtitulo.copyWith(
              fontWeight: FontWeight.w400,
              color: colores.textoSecundario,
            ),
          ),
        ),
        Text(
          FormatoViaje.hora(hora),
          style: tipografia.numeroMetrica.copyWith(
            fontWeight: FontWeight.w700,
            color: colores.textoPrincipal,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.m,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjetaDestacada),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        children: [
          fila(
            Container(
              width: Medidas.puntoRecorrido,
              height: Medidas.puntoRecorrido,
              decoration: BoxDecoration(
                color: colores.primario,
                shape: BoxShape.circle,
              ),
            ),
            'Salida',
            recorrido.salida,
          ),
          Row(
            children: [
              SizedBox(
                width: Medidas.icono,
                height: Espacios.xl,
                child: CustomPaint(
                  painter: _LineaPunteada(color: colores.bordeFuerte),
                ),
              ),
            ],
          ),
          fila(
            Container(
              width: Medidas.puntoRecorrido,
              height: Medidas.puntoRecorrido,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorLlegada, width: 3),
              ),
            ),
            'Llegada',
            recorrido.llegada,
          ),
        ],
      ),
    );
  }
}

/// Línea vertical punteada centrada.
class _LineaPunteada extends CustomPainter {
  _LineaPunteada({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    dibujarPunteado(
      canvas,
      Path()
        ..moveTo(x, 2)
        ..lineTo(x, size.height - 2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
      guion: 3,
      espacio: 4,
    );
  }

  @override
  bool shouldRepaint(_LineaPunteada oldDelegate) => oldDelegate.color != color;
}
