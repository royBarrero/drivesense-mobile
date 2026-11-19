import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../recorridos/presentation/live_trip_screen.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/event_counts_row.dart';
import '../../recorridos/presentation/widgets/live_alert_capsules.dart';
import '../../recorridos/presentation/widgets/map_button.dart';
import '../../recorridos/presentation/widgets/trip_map.dart';
import '../../recorridos/providers/trip_provider.dart';
import '../../telemetria/models/live_alerts.dart';
import '../../telemetria/providers/learning_mode_provider.dart';
import '../models/route_plan.dart';
import '../models/route_progress.dart';
import '../models/voice_guide.dart';
import '../providers/copilot_provider.dart';
import 'route_format.dart';

/// Viaje en vivo con destino (HU-31, diseño "maniobra arriba + mapa"): la
/// próxima maniobra en el bloque oscuro, el mapa que sigue la posición sobre
/// la ruta con la velocidad (y los avisos de HU-14) y los botones de silencio
/// y aprendizaje, y abajo lo que falta, los eventos y "Finalizar viaje".
class VistaViajeCopiloto extends ConsumerStatefulWidget {
  const VistaViajeCopiloto({
    super.key,
    required this.viaje,
    required this.alVolver,
    required this.alFinalizar,
    required this.finalizando,
    this.error,
  });

  final ViajeEnCurso viaje;
  final VoidCallback alVolver;
  final VoidCallback alFinalizar;
  final bool finalizando;
  final String? error;

  @override
  ConsumerState<VistaViajeCopiloto> createState() => _VistaViajeCopilotoState();
}

class _VistaViajeCopilotoState extends ConsumerState<VistaViajeCopiloto> {
  final _mapa = ControladorMapaDestino();
  bool _siguiendo = true;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estado = ref.watch(copilotoProvider);
    final viaje = widget.viaje;
    final destino = estado?.destino ?? viaje.viaje.destino;
    final ultima = viaje.viaje.acumulador.ultimaLectura;
    final progreso = estado?.progreso;
    final ruta = estado?.ruta;

    // Sobre la ruta, la posición se dibuja en ella; desviado, donde está
    final Coordenada? ubicacion = switch ((progreso, ultima)) {
      (final p?, _) when p.distanciaARutaM <= UmbralesCopiloto.desvioM =>
        p.posicion,
      (_, final l?) => Coordenada(l.latitud, l.longitud),
      (final p?, null) => p.posicion,
      _ => null,
    };
    final (hecho, pendiente) = _partir(ruta, progreso);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BloqueManiobra(
          viaje: viaje,
          estado: estado,
          destino: destino,
          alVolver: widget.alVolver,
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ubicacion == null
                    ? ColoredBox(color: colores.superficieAlt)
                    : MapaDestino(
                        ubicacion: ubicacion,
                        destino: destino?.posicion,
                        trazado: pendiente,
                        recorrido: hecho,
                        seguir: _siguiendo,
                        controlador: _mapa,
                        alMoverManual: () {
                          if (_siguiendo) setState(() => _siguiendo = false);
                        },
                      ),
              ),
              Positioned(
                left: Espacios.m,
                bottom: Espacios.m,
                child: _CapsulaVelocidad(viaje: viaje),
              ),
              Positioned(
                right: Espacios.m,
                top: Espacios.m,
                child: Column(
                  children: [
                    _BotonAlternar(
                      activo: !(estado?.silenciado ?? false),
                      icono: (estado?.silenciado ?? false)
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      descripcion: (estado?.silenciado ?? false)
                          ? 'Activar la voz'
                          : 'Silenciar la voz',
                      alPresionar: () => ref
                          .read(copilotoProvider.notifier)
                          .silenciar(!(estado?.silenciado ?? false)),
                    ),
                    const SizedBox(height: Espacios.s),
                    _BotonAlternar(
                      activo: ref.watch(modoAprendizajeProvider).value ?? false,
                      icono: Icons.school_outlined,
                      descripcion: 'Modo aprendizaje',
                      alPresionar: () {
                        final activo =
                            ref.read(modoAprendizajeProvider).value ?? false;
                        ref
                            .read(modoAprendizajeProvider.notifier)
                            .cambiar(!activo);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                activo
                                    ? 'Modo aprendizaje desactivado'
                                    : 'Modo aprendizaje activado: consejos por '
                                          'voz tras cada evento',
                              ),
                            ),
                          );
                      },
                    ),
                  ],
                ),
              ),
              if (!_siguiendo)
                Positioned(
                  right: Espacios.m,
                  bottom: Espacios.m,
                  child: BotonMapa(
                    icono: Icons.my_location_rounded,
                    descripcion: 'Centrar',
                    alPresionar: () {
                      setState(() => _siguiendo = true);
                      _mapa.centrar();
                    },
                  ),
                ),
            ],
          ),
        ),
        _PieViaje(
          viaje: viaje,
          progreso: progreso,
          llego: estado?.llego ?? false,
          error: widget.error,
          finalizando: widget.finalizando,
          alFinalizar: widget.alFinalizar,
        ),
      ],
    );
  }

  /// Trazado dividido en lo hecho (hasta la posición) y lo que falta.
  static (List<Coordenada>, List<Coordenada>) _partir(
    RutaPlaneada? ruta,
    ProgresoRuta? progreso,
  ) {
    if (ruta == null) return (const [], const []);
    if (progreso == null) return (const [], ruta.trazado);
    final corte = progreso.segmento + 1;
    return (
      [...ruta.trazado.take(corte), progreso.posicion],
      [progreso.posicion, ...ruta.trazado.skip(corte)],
    );
  }
}

/// Bloque oscuro: estado del Copiloto, GPS y la próxima maniobra.
class _BloqueManiobra extends StatelessWidget {
  const _BloqueManiobra({
    required this.viaje,
    required this.estado,
    required this.destino,
    required this.alVolver,
  });

  final ViajeEnCurso viaje;
  final EstadoCopiloto? estado;
  final Destino? destino;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estado = this.estado;
    final aviso = estado == null
        ? null
        : estado.recalculando
        ? 'Recalculando…'
        : estado.sinConexion
        ? 'Sin conexión'
        : null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: ColoredBox(
        color: colores.encabezadoFondo,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacios.l,
              Espacios.xs,
              Espacios.l,
              Espacios.l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BotonVolverEnVivo(alPresionar: alVolver),
                    Expanded(
                      child: Center(
                        child: aviso == null
                            ? CapsulaEnVivo(
                                fondo: colores.acentoOscuroTenue,
                                color: colores.encabezadoAcento,
                                punto: true,
                                texto: 'Copiloto',
                              )
                            : CapsulaEnVivo(
                                borde: colores.advertencia,
                                color: colores.advertencia,
                                icono: estado!.sinConexion
                                    ? Icons.cloud_off_outlined
                                    : Icons.sync_rounded,
                                texto: aviso,
                              ),
                      ),
                    ),
                    viaje.sinSenal
                        ? CapsulaEnVivo(
                            borde: colores.advertencia,
                            color: colores.advertencia,
                            icono: Icons.gps_not_fixed,
                            texto: 'Sin señal',
                          )
                        : CapsulaEnVivo(
                            borde: colores.encabezadoBorde,
                            color: colores.encabezadoTextoSecundario,
                            icono: Icons.gps_fixed,
                            texto: 'GPS',
                          ),
                  ],
                ),
                const SizedBox(height: Espacios.l),
                _Maniobra(estado: estado, destino: destino),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Maniobra extends StatelessWidget {
  const _Maniobra({required this.estado, required this.destino});

  final EstadoCopiloto? estado;
  final Destino? destino;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estado = this.estado;
    final progreso = estado?.progreso;
    final proxima = progreso?.proxima;

    final (
      IconData icono,
      String? distancia,
      String titulo,
      String? detalle,
    ) = switch (estado) {
      EstadoCopiloto(llego: true) => (
        Icons.flag_rounded,
        null,
        'Llegaste a tu destino',
        destino?.nombre,
      ),
      EstadoCopiloto(sinRuta: true) => (
        Icons.wrong_location_outlined,
        null,
        'Sin ruta por ahora',
        'El viaje se sigue registrando.',
      ),
      _ when proxima == null => (
        Icons.route_outlined,
        null,
        'Calculando la ruta…',
        destino?.nombre,
      ),
      _ => (
        FormatoRuta.icono(proxima.tipo),
        FormatoRuta.distancia(progreso!.hastaProximaM),
        GuiaVoz.titulo(proxima),
        proxima.calle ?? destino?.nombre,
      ),
    };

    // Después de la próxima: la siguiente maniobra y a cuánto de ella
    final pasos = estado?.ruta?.pasos ?? const <PasoRuta>[];
    final indiceLuego = (progreso?.indiceProxima ?? -2) + 1;
    final luego =
        estado?.llego != true && indiceLuego > 0 && indiceLuego < pasos.length
        ? pasos[indiceLuego]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: Medidas.cajaManiobra,
              height: Medidas.cajaManiobra,
              decoration: BoxDecoration(
                color: colores.encabezadoSuperficie,
                borderRadius: BorderRadius.circular(Radios.micro),
                border: Border.all(color: colores.encabezadoBorde),
              ),
              child: Icon(
                icono,
                size: Medidas.iconoManiobra,
                color: colores.encabezadoAcento,
              ),
            ),
            const SizedBox(width: Espacios.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (distancia != null)
                    Text(
                      distancia,
                      style: tipografia.numeroGrande.copyWith(
                        color: colores.encabezadoTexto,
                      ),
                    ),
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tipografia.subtituloGrande.copyWith(
                      color: colores.encabezadoTexto,
                    ),
                  ),
                  if (detalle != null)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tipografia.cuerpo.copyWith(
                        color: colores.encabezadoTextoSecundario,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (luego != null && luego.tipo != TipoPaso.llegada) ...[
          const SizedBox(height: Espacios.s),
          Row(
            children: [
              Text(
                'Luego:',
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.encabezadoTextoSecundario,
                ),
              ),
              const SizedBox(width: Espacios.xs),
              Icon(
                FormatoRuta.icono(luego.tipo),
                size: Medidas.iconoPequeno,
                color: colores.encabezadoTexto,
              ),
              const SizedBox(width: Espacios.xxs),
              Text(
                'en ${FormatoRuta.distancia(proxima!.distanciaM)}',
                style: tipografia.cuerpoPequeno.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colores.encabezadoTexto,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Velocidad sobre el mapa; un evento puntual o un exceso (HU-14) la
/// reemplazan con su cápsula, como en el bloque del viaje libre.
class _CapsulaVelocidad extends StatelessWidget {
  const _CapsulaVelocidad({required this.viaje});

  final ViajeEnCurso viaje;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final aviso = viaje.aviso;
    return SizedBox(
      height: Medidas.altoCapsulaVelocidad,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (actual, anteriores) =>
            Align(alignment: Alignment.centerLeft, child: actual),
        child: switch (aviso) {
          AvisoPuntual(:final tipo) => CapsulaEvento(
            key: ValueKey(tipo),
            tipo: tipo,
          ),
          AvisoExceso(:final duracionS) => CapsulaExceso(
            key: const ValueKey('exceso'),
            duracionS: duracionS,
          ),
          SinAviso() => Container(
            key: const ValueKey('velocidad'),
            height: Medidas.altoCapsulaVelocidad,
            padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
            decoration: BoxDecoration(
              color: colores.encabezadoFondo,
              borderRadius: BorderRadius.circular(Radios.pildora),
              boxShadow: colores.sombraTarjeta,
            ),
            // Centrada en el alto de la cápsula
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      FormatoViaje.velocidad(viaje.velocidadKmh),
                      style: tipografia.numeroGrande.copyWith(
                        color: colores.encabezadoTexto,
                      ),
                    ),
                    const SizedBox(width: Espacios.xxs),
                    Text(
                      'km/h',
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.encabezadoTextoSecundario,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

/// Botón redondo sobre el mapa con estado: activo en el bloque oscuro con el
/// ícono en el acento; inactivo, blanco.
class _BotonAlternar extends StatelessWidget {
  const _BotonAlternar({
    required this.activo,
    required this.icono,
    required this.descripcion,
    required this.alPresionar,
  });

  final bool activo;
  final IconData icono;
  final String descripcion;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        shadows: colores.sombraTarjeta,
      ),
      child: Material(
        color: activo ? colores.encabezadoFondo : colores.superficie,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: alPresionar,
          child: Tooltip(
            message: descripcion,
            child: Semantics(
              toggled: activo,
              child: SizedBox.square(
                dimension: Medidas.botonVolver,
                child: Icon(
                  icono,
                  size: Medidas.iconoNavegacion,
                  color: activo
                      ? colores.encabezadoAcento
                      : colores.textoSecundario,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parte clara de abajo: lo que falta, los eventos y "Finalizar viaje".
class _PieViaje extends StatelessWidget {
  const _PieViaje({
    required this.viaje,
    required this.progreso,
    required this.llego,
    required this.error,
    required this.finalizando,
    required this.alFinalizar,
  });

  final ViajeEnCurso viaje;
  final ProgresoRuta? progreso;
  final bool llego;
  final String? error;
  final bool finalizando;
  final VoidCallback alFinalizar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final progreso = this.progreso;
    final faltan = llego
        ? 'Llegaste · ${FormatoViaje.kilometros(viaje.distanciaM)} km recorridos'
        : progreso == null
        ? '${FormatoViaje.kilometros(viaje.distanciaM)} km recorridos'
        : 'Faltan ${FormatoRuta.distancia(progreso.faltanM)} · '
              '${FormatoRuta.duracion(progreso.faltanS)}';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacios.l,
          Espacios.m,
          Espacios.l,
          Espacios.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    faltan,
                    style: tipografia.subtitulo.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colores.textoPrincipal,
                    ),
                  ),
                ),
                Text(
                  FormatoViaje.duracion(viaje.duracionS),
                  style: tipografia.numeroMetrica.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colores.textoSecundario,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacios.m),
            FilaConteoEventos(
              conteo: FilaConteoEventos.contar(viaje.viaje.eventos),
            ),
            const SizedBox(height: Espacios.m),
            if (error != null) ...[
              AvisoError(mensaje: error!),
              const SizedBox(height: Espacios.m),
            ],
            BotonPrimario(
              texto: 'Finalizar viaje',
              icono: Icons.stop_rounded,
              cargando: finalizando,
              alPresionar: alFinalizar,
            ),
          ],
        ),
      ),
    );
  }
}
