import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/period_chips.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/label.dart';
import '../models/trip_history.dart';
import '../providers/trip_history_provider.dart';
import '../providers/trip_provider.dart';
import 'trip_format.dart';
import 'widgets/load_error.dart';
import 'widgets/location_permission_flow.dart';
import 'widgets/trip_row.dart';

/// Pestaña Viajes: historial de viajes finalizados (HU-06).
///
/// Filtro por periodo, resumen del periodo y lista agrupada por día que carga
/// más viajes al llegar al final. Sin ningún viaje: ilustración e "Iniciar recorrido".
class ViajesPantalla extends ConsumerStatefulWidget {
  const ViajesPantalla({super.key});

  @override
  ConsumerState<ViajesPantalla> createState() => _ViajesPantallaState();
}

class _ViajesPantallaState extends ConsumerState<ViajesPantalla> {
  PeriodoHistorial _periodo = PeriodoHistorial.semana;

  /// Distancia al final de la lista desde la que se pide la página siguiente.
  static const _margenCargaMas = 400.0;

  Future<void> _refrescar() async {
    try {
      ref.invalidate(historialProvider(_periodo));
      await ref.read(historialProvider(_periodo).future);
    } catch (_) {
      // El error se muestra con el estado del provider
    }
  }

  bool _alDesplazar(ScrollNotification notificacion) {
    if (notificacion.metrics.extentAfter < _margenCargaMas) {
      ref.read(historialProvider(_periodo).notifier).cargarMas();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final historial = ref.watch(historialProvider(_periodo));
    final estado = historial.value;
    final conError = historial.hasError && !historial.isLoading;
    final sinViajes = !conError && (estado?.sinViajes ?? false);

    final List<Widget> contenido;
    if (conError) {
      contenido = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorCarga(
              error: historial.error!,
              alReintentar: () => ref.invalidate(historialProvider(_periodo)),
            ),
          ),
        ),
      ];
    } else if (estado == null) {
      contenido = const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (sinViajes) {
      contenido = const [
        SliverFillRemaining(hasScrollBody: false, child: _SinViajes()),
      ];
    } else {
      contenido = [
        SliverToBoxAdapter(child: _TarjetaResumen(resumen: estado.resumen)),
        if (estado.recorridos.isEmpty)
          SliverToBoxAdapter(child: _PeriodoVacio(periodo: _periodo))
        else
          _ListaAgrupada(recorridos: estado.recorridos),
        SliverToBoxAdapter(
          child: _PieLista(
            estado: estado,
            alReintentar: () =>
                ref.read(historialProvider(_periodo).notifier).cargarMas(),
          ),
        ),
      ];
    }

    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: _alDesplazar,
        child: RefreshIndicator(
          onRefresh: _refrescar,
          color: colores.primarioOscuro,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Espacios.l,
                  Espacios.l,
                  Espacios.l,
                  // El contenido pasa por detrás de la barra inferior
                  MediaQuery.paddingOf(context).bottom + Espacios.l,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Text(
                        'Mis viajes',
                        style: tipografia.titulo.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                    ),
                    if (!sinViajes)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Espacios.m,
                          ),
                          child: ChipsPeriodo(
                            opciones: PeriodoHistorial.values,
                            texto: (periodo) => periodo.texto,
                            seleccionado: _periodo,
                            alSeleccionar: (periodo) =>
                                setState(() => _periodo = periodo),
                          ),
                        ),
                      ),
                    ...contenido,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con el degradado del DriveScore: viajes, km y tiempo al volante.
class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.resumen});

  final ResumenPeriodo resumen;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radios.tarjeta),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: colores.gradienteScore),
        child: Stack(
          children: [
            // Diana recortada en la esquina superior derecha
            Positioned(
              top: -Espacios.xxl,
              right: -Espacios.xxl,
              width: Medidas.ilustracionVacia,
              height: Medidas.ilustracionVacia,
              child: CustomPaint(
                painter: CirculosReducidosPainter(
                  colorLineas: colores.lineasSobreGradiente,
                  escala: 1.6,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Espacios.l),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DatoResumen(
                      partes: [('${resumen.viajes}', null)],
                      etiqueta: resumen.viajes == 1 ? 'Viaje' : 'Viajes',
                    ),
                  ),
                  Expanded(
                    child: _DatoResumen(
                      partes: [
                        (FormatoViaje.kilometros(resumen.distanciaM), 'km'),
                      ],
                      etiqueta: 'Recorridos',
                    ),
                  ),
                  Expanded(
                    child: _DatoResumen(
                      partes: FormatoViaje.duracionPartes(resumen.duracionS),
                      etiqueta: 'Al volante',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({required this.partes, required this.etiqueta});

  /// Número en grande y su unidad (opcional) en pequeño.
  final List<(String, String?)> partes;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final unidad = tipografia.cuerpoPequeno.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          // "12 h 30 min" se reduce en vez de desbordar la columna
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                for (final (indice, (valor, unidadTexto))
                    in partes.indexed) ...[
                  if (indice > 0) const TextSpan(text: ' '),
                  TextSpan(text: valor),
                  if (unidadTexto != null)
                    TextSpan(text: ' $unidadTexto', style: unidad),
                ],
              ],
            ),
            style: tipografia.puntaje.copyWith(
              color: colores.textoSobreGradiente,
            ),
          ),
        ),
        const SizedBox(height: Espacios.xxs),
        Text(
          etiqueta,
          style: tipografia.cuerpoPequeno.copyWith(
            color: colores.textoSobreGradiente,
          ),
        ),
      ],
    );
  }
}

/// Viajes agrupados por el día de salida: "Hoy", "Ayer" o la fecha.
class _ListaAgrupada extends StatelessWidget {
  const _ListaAgrupada({required this.recorridos});

  final List<RecorridoHistorial> recorridos;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final elementos = <Widget>[];
    String? diaAnterior;
    for (final (indice, recorrido) in recorridos.indexed) {
      final dia = FormatoViaje.dia(recorrido.salida, ahora: ahora);
      if (dia != diaAnterior) {
        diaAnterior = dia;
        elementos.add(
          Padding(
            padding: const EdgeInsets.only(top: Espacios.l, bottom: Espacios.s),
            child: Etiqueta(dia, grande: true),
          ),
        );
      } else {
        elementos.add(const SizedBox(height: Espacios.s));
      }
      elementos.add(
        FilaViaje(
          recorrido: recorrido,
          indice: indice,
          alPresionar: () => context.push(Rutas.detalleViaje(recorrido.id)),
        ),
      );
    }
    return SliverList.list(children: elementos);
  }
}

/// Pie de la lista: cargando la página siguiente, o su error con "Reintentar".
class _PieLista extends StatelessWidget {
  const _PieLista({required this.estado, required this.alReintentar});

  final EstadoHistorial estado;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    if (estado.cargandoMas) {
      return const Padding(
        padding: EdgeInsets.all(Espacios.l),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = estado.errorMas;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Espacios.m),
      child: Column(
        children: [
          AvisoError(mensaje: error),
          TextButton(onPressed: alReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// El periodo no tiene viajes, pero hay viajes en otros periodos.
class _PeriodoVacio extends StatelessWidget {
  const _PeriodoVacio({required this.periodo});

  final PeriodoHistorial periodo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacios.xxl),
      child: Text(
        periodo == PeriodoHistorial.semana
            ? 'No tienes viajes esta semana.'
            : 'No tienes viajes este mes.',
        textAlign: TextAlign.center,
        style: context.tipografia.cuerpo.copyWith(
          color: colores.textoSecundario,
        ),
      ),
    );
  }
}

/// Ningún viaje finalizado todavía: ilustración e "Iniciar recorrido".
class _SinViajes extends ConsumerStatefulWidget {
  const _SinViajes();

  @override
  ConsumerState<_SinViajes> createState() => _SinViajesState();
}

class _SinViajesState extends ConsumerState<_SinViajes> {
  // Como en el encabezado del login: el texto no se estira a todo el ancho
  static const _anchoMaximoTexto = 260.0;

  bool _ocupado = false;
  String? _error;

  Future<void> _iniciar() async {
    switch (ref.read(viajeProvider).value) {
      // Ya hay uno: se vuelve a él, o a Inicio para continuarlo o finalizarlo
      case ViajeEnCurso():
        context.push(Rutas.recorrido);
        return;
      case ViajeInterrumpido():
        context.go(Rutas.inicio);
        return;
      default:
    }
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await iniciarViaje(context, ref);
    } on ErrorRecorrido catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final consultandoViaje = ref.watch(viajeProvider).isLoading;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: Medidas.ilustracionVacia,
            child: CustomPaint(
              painter: IlustracionHistorialVacioPainter(
                colorLineas: colores.bordeFuerte,
                gradiente: colores.gradienteScore,
              ),
            ),
          ),
          const SizedBox(height: Espacios.xl),
          Text(
            'Aún no tienes viajes',
            textAlign: TextAlign.center,
            style: tipografia.tituloTarjeta.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
          const SizedBox(height: Espacios.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximoTexto),
            child: Text(
              'Tus recorridos aparecerán aquí cuando finalices tu primer viaje.',
              textAlign: TextAlign.center,
              style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
            ),
          ),
          const SizedBox(height: Espacios.xl),
          _BotonIniciarOscuro(
            cargando: _ocupado || consultandoViaje,
            alPresionar: _iniciar,
          ),
          if (_error case final error?) ...[
            const SizedBox(height: Espacios.m),
            AvisoError(mensaje: error),
          ],
        ],
      ),
    );
  }
}

/// Píldora oscura con el círculo de acento y el ícono de play.
class _BotonIniciarOscuro extends StatelessWidget {
  const _BotonIniciarOscuro({
    required this.cargando,
    required this.alPresionar,
  });

  final bool cargando;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;

    return SizedBox(
      height: Medidas.altoBotonFormulario,
      child: FilledButton(
        onPressed: cargando ? null : alPresionar,
        style: FilledButton.styleFrom(
          backgroundColor: colores.textoPrincipal,
          foregroundColor: colores.sobrePrimario,
          // Mientras carga se mantiene el color
          disabledBackgroundColor: colores.textoPrincipal,
          disabledForegroundColor: colores.sobrePrimario,
          // Se ajusta al contenido (el tema lo estira a todo el ancho)
          minimumSize: const Size(0, Medidas.altoBotonFormulario),
          padding: const EdgeInsets.only(left: Espacios.xl, right: Espacios.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Iniciar recorrido'),
            const SizedBox(width: Espacios.m),
            Container(
              width: Medidas.cajaIconoFila,
              height: Medidas.cajaIconoFila,
              decoration: BoxDecoration(
                color: colores.encabezadoAcento,
                shape: BoxShape.circle,
              ),
              child: cargando
                  ? Padding(
                      padding: const EdgeInsets.all(Espacios.s),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colores.sobreAcentoOscuro,
                      ),
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      size: Medidas.iconoNavegacion,
                      color: colores.sobreAcentoOscuro,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
