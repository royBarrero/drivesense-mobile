import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/logo.dart';
import '../../auth/providers/session_provider.dart';
import '../../puntaje/models/score_history.dart';
import '../../puntaje/presentation/widgets/trend_badge.dart';
import '../../puntaje/providers/score_history_provider.dart';
import '../../recorridos/models/trip_history.dart';
import '../../recorridos/models/trip_score.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/drive_score_ring.dart';
import '../../recorridos/presentation/widgets/location_permission_flow.dart';
import '../../recorridos/presentation/widgets/score_breakdown.dart';
import '../../recorridos/providers/pending_summary_provider.dart';
import '../../recorridos/providers/trip_history_provider.dart';
import '../../recorridos/providers/trip_provider.dart';

/// "Buenos días" hasta las 12, "Buenas tardes" hasta las 19 y "Buenas noches"
/// después.
String saludoSegunHora(DateTime ahora) => switch (ahora.hour) {
  < 12 => 'Buenos días',
  < 19 => 'Buenas tardes',
  _ => 'Buenas noches',
};

/// Pestaña Inicio (diseño B): encabezado oscuro con el saludo y el DriveScore
/// de los últimos 7 días (HU-17), el botón del recorrido flotando sobre su
/// borde, el resumen de la semana y el último viaje (HU-06).
class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key, this.reloj = DateTime.now});

  /// Hora para el saludo; se reemplaza en las pruebas.
  final DateTime Function() reloj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayUltimo = ref.watch(ultimoViajeProvider).value != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos claros sobre el encabezado oscuro; las otras pestañas usan los
      // oscuros de la barra principal
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + Espacios.l,
        ),
        children: [
          _EncabezadoYRecorrido(reloj: reloj),
          const Padding(
            padding: EdgeInsets.fromLTRB(Espacios.l, Espacios.l, Espacios.l, 0),
            child: _EstaSemana(),
          ),
          if (hayUltimo)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Espacios.l,
                Espacios.m,
                Espacios.l,
                0,
              ),
              child: _UltimoViaje(),
            ),
        ],
      ),
    );
  }
}

/// Encabezado oscuro con el botón del recorrido montado sobre su borde, y los
/// avisos del recorrido (viaje sin terminar, resumen pendiente, errores).
///
/// Conserva la lógica de la tarjeta anterior: iniciar, volver al viaje en
/// curso, o continuar/finalizar uno interrumpido. Mientras hay un viaje no se
/// puede iniciar otro.
class _EncabezadoYRecorrido extends ConsumerStatefulWidget {
  const _EncabezadoYRecorrido({required this.reloj});

  final DateTime Function() reloj;

  @override
  ConsumerState<_EncabezadoYRecorrido> createState() =>
      _EncabezadoYRecorridoState();
}

class _EncabezadoYRecorridoState extends ConsumerState<_EncabezadoYRecorrido> {
  bool _ocupado = false;
  String? _error;

  /// Ejecuta una acción mostrando el indicador y su error, si lo hay.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on ErrorRecorrido catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _iniciar() => _ejecutar(() => iniciarViaje(context, ref));

  Future<void> _continuar() => _ejecutar(() async {
    if (!await prepararUbicacion(context, ref)) return;
    ref.read(viajeProvider.notifier).continuar();
    if (mounted) context.push(Rutas.recorrido);
  });

  Future<void> _finalizar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Finalizar el viaje?'),
        content: const Text(
          'Se guardará con lo registrado hasta que se cerró la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _ejecutar(() async {
      await ref.read(viajeProvider.notifier).finalizar();
      if (mounted) context.go(Rutas.resumenRecorrido);
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(viajeProvider);
    final viaje = estado.value;
    final hayPendiente = ref.watch(resumenPendienteProvider).value != null;

    final (String texto, IconData icono, VoidCallback accion) = switch (viaje) {
      ViajeEnCurso() => (
        'Volver al viaje',
        Icons.navigation_rounded,
        () => context.push(Rutas.recorrido),
      ),
      ViajeInterrumpido() => (
        'Continuar viaje',
        Icons.play_arrow_rounded,
        _continuar,
      ),
      _ => ('Iniciar recorrido', Icons.play_arrow_rounded, _iniciar),
    };
    // Mientras se consulta si hay un viaje en curso no se puede iniciar
    final cargando = _ocupado || (viaje is! ViajeEnCurso && estado.isLoading);

    final avisos = <Widget>[
      if (viaje is ViajeInterrumpido)
        _AvisoSinTerminar(
          inicio: viaje.viaje.acumulador.inicio,
          alFinalizar: _ocupado ? null : _finalizar,
        ),
      if (hayPendiente) const _AvisoPendiente(),
      if (_error case final error?) AvisoError(mensaje: error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                bottom: Medidas.altoBotonInicio / 2,
              ),
              child: _Encabezado(reloj: widget.reloj),
            ),
            Positioned(
              left: Espacios.l,
              right: Espacios.l,
              bottom: 0,
              child: _BotonRecorrido(
                texto: texto,
                icono: icono,
                cargando: cargando,
                alPresionar: accion,
              ),
            ),
          ],
        ),
        for (final aviso in avisos)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacios.l,
              Espacios.m,
              Espacios.l,
              0,
            ),
            child: aviso,
          ),
      ],
    );
  }
}

/// Bloque oscuro: logo y avatar, saludo con el nombre, la línea del DriveScore
/// y, a la derecha, el anillo de los últimos 7 días.
class _Encabezado extends ConsumerWidget {
  const _Encabezado({required this.reloj});

  final DateTime Function() reloj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final nombre = ref.watch(sesionProvider).value?.nombre ?? '';
    final primerNombre = nombre.trim().split(RegExp(r'\s+')).first;
    final estado = ref.watch(historicoPuntajeProvider(PeriodoPuntaje.dias7));
    final historico = estado.value;
    final conError = estado.hasError && !estado.isLoading;

    // Los mismos casos de la tarjeta de HU-17
    final int? puntaje = switch (historico) {
      _ when conError => null,
      null => null,
      HistoricoPuntaje(viajesTotales: 0) => null,
      HistoricoPuntaje(:final viajesTotales, :final promedioTotal)
          when viajesTotales < HistoricoPuntaje.viajesParaEvolucion =>
        promedioTotal,
      HistoricoPuntaje(:final promedio) => promedio,
    };
    final abreMiDriveScore =
        !conError && historico != null && historico.viajesTotales > 0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: ColoredBox(
        color: colores.encabezadoFondo,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IlustracionRutaPainter(
                  colorLineas: colores.encabezadoBorde,
                  colorAcento: colores.acentoOscuroTenue,
                  // Centrada detrás del anillo
                  centro: (tamano) => Offset(
                    tamano.width -
                        Espacios.l -
                        Medidas.anilloEncabezadoInicio / 2,
                    tamano.height * 0.5,
                  ),
                  escala: 1.5,
                  conPunto: false,
                  // La ruta no pasa por detrás del anillo
                  huecoCentral: Medidas.anilloEncabezadoInicio / 2 + Espacios.s,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacios.l,
                  Espacios.m,
                  Espacios.l,
                  // Deja lugar a la mitad del botón que monta sobre el borde
                  Espacios.l + Medidas.altoBotonInicio / 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const LogoDriveSense(),
                        const Spacer(),
                        Avatar(nombre: nombre, sobreOscuro: true),
                      ],
                    ),
                    const SizedBox(height: Espacios.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${saludoSegunHora(reloj())},',
                                style: tipografia.saludo.copyWith(
                                  color: colores.encabezadoTextoSecundario,
                                ),
                              ),
                              const SizedBox(height: Espacios.xxs),
                              Text(
                                primerNombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tipografia.nombreSaludo.copyWith(
                                  color: colores.encabezadoTexto,
                                ),
                              ),
                              const SizedBox(height: Espacios.s),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: Medidas.altoLineaEstadoInicio,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _LineaEstado(
                                    historico: historico,
                                    conError: conError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Espacios.m),
                        Semantics(
                          button: abreMiDriveScore,
                          label: 'Mi DriveScore',
                          child: GestureDetector(
                            onTap: abreMiDriveScore
                                ? () => context.push(Rutas.miDriveScore)
                                : null,
                            child: AnilloDriveScore(
                              puntaje: puntaje,
                              tamano: Medidas.anilloEncabezadoInicio,
                            ),
                          ),
                        ),
                      ],
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

/// Bajo el nombre: la tendencia o lo que corresponde según los viajes.
class _LineaEstado extends ConsumerWidget {
  const _LineaEstado({required this.historico, required this.conError});

  final HistoricoPuntaje? historico;
  final bool conError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final estilo = context.tipografia.cuerpoPequeno.copyWith(
      color: colores.encabezadoTextoSecundario,
    );
    final historico = this.historico;

    if (conError) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('No se pudo cargar tu DriveScore.', style: estilo),
          TextButton(
            onPressed: () =>
                ref.invalidate(historicoPuntajeProvider(PeriodoPuntaje.dias7)),
            style: TextButton.styleFrom(
              foregroundColor: colores.encabezadoAcento,
              padding: const EdgeInsets.symmetric(horizontal: Espacios.xs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    // Cargando: el espacio queda reservado
    if (historico == null) return const SizedBox.shrink();

    final totales = historico.viajesTotales;
    if (totales == 0) {
      return Text(
        'Tu DriveScore aparecerá después de tu primer viaje',
        style: estilo,
      );
    }
    if (totales < HistoricoPuntaje.viajesParaEvolucion) {
      final faltan = HistoricoPuntaje.viajesParaEvolucion - totales;
      return Text(
        'Haz $faltan ${faltan == 1 ? 'viaje' : 'viajes'} más para ver tu '
        'evolución',
        style: estilo,
      );
    }
    if (historico.viajes == 0) {
      return Text('Sin viajes en los últimos 7 días', style: estilo);
    }
    final tendencia = historico.tendencia;
    if (tendencia == null) return const SizedBox.shrink();
    return CapsulaTendencia(
      tendencia: tendencia,
      sufijo: 'en 7 días',
      sobreOscuro: true,
    );
  }
}

/// Botón píldora de acento que flota sobre el borde del encabezado: texto a la
/// izquierda y, a la derecha, un círculo oscuro con el ícono.
class _BotonRecorrido extends StatelessWidget {
  const _BotonRecorrido({
    required this.texto,
    required this.icono,
    required this.cargando,
    required this.alPresionar,
  });

  final String texto;
  final IconData icono;
  final bool cargando;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    const margen = (Medidas.altoBotonInicio - Medidas.circuloBotonInicio) / 2;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: colores.sombraBotonAcento,
      ),
      child: Material(
        color: colores.encabezadoAcento,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: cargando ? null : alPresionar,
          overlayColor: WidgetStatePropertyAll(
            colores.sobreAcentoOscuro.withValues(alpha: 0.08),
          ),
          child: SizedBox(
            height: Medidas.altoBotonInicio,
            child: Row(
              children: [
                const SizedBox(width: Espacios.xl),
                Expanded(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tipografia.botonGrande.copyWith(
                      color: colores.sobreAcentoOscuro,
                    ),
                  ),
                ),
                Container(
                  width: Medidas.circuloBotonInicio,
                  height: Medidas.circuloBotonInicio,
                  margin: const EdgeInsets.all(margen),
                  decoration: BoxDecoration(
                    color: colores.encabezadoFondo,
                    shape: BoxShape.circle,
                  ),
                  child: cargando
                      ? Padding(
                          padding: const EdgeInsets.all(Espacios.s),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colores.encabezadoAcento,
                          ),
                        )
                      : Icon(
                          icono,
                          size: Medidas.iconoNavegacion,
                          color: colores.encabezadoAcento,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Viaje interrumpido: cuándo empezó y "Finalizar" (continuar va en el botón).
class _AvisoSinTerminar extends StatelessWidget {
  const _AvisoSinTerminar({required this.inicio, required this.alFinalizar});

  final DateTime inicio;
  final VoidCallback? alFinalizar;

  /// "hoy a las 08:05" o "el 26/09 a las 18:40".
  static String _cuando(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final local = fecha.toLocal();
    final ahora = DateTime.now();
    final hora = '${dos(local.hour)}:${dos(local.minute)}';
    final esHoy =
        local.year == ahora.year &&
        local.month == ahora.month &&
        local.day == ahora.day;
    return esHoy
        ? 'hoy a las $hora'
        : 'el ${dos(local.day)}/${dos(local.month)} a las $hora';
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Espacios.m,
        Espacios.s,
        Espacios.xs,
        Espacios.s,
      ),
      decoration: BoxDecoration(
        color: colores.tinteAdvertencia,
        borderRadius: BorderRadius.circular(Radios.campo),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            size: Medidas.icono,
            color: colores.advertencia,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              'Tienes un viaje sin terminar. Lo iniciaste ${_cuando(inicio)}.',
              style: tipografia.cuerpoPequeno.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
          ),
          TextButton(onPressed: alFinalizar, child: const Text('Finalizar')),
        ],
      ),
    );
  }
}

class _AvisoPendiente extends StatelessWidget {
  const _AvisoPendiente();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
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
            Icons.cloud_upload_outlined,
            size: Medidas.icono,
            color: colores.advertencia,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              'Tienes un viaje pendiente de envío. Se enviará automáticamente '
              'cuando haya conexión.',
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

/// "Esta semana" (desde el lunes, como el historial): viajes, km y tiempo al
/// volante, con el enlace a la pestaña Viajes.
class _EstaSemana extends ConsumerWidget {
  const _EstaSemana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final resumen = ref
        .watch(historialProvider(PeriodoHistorial.semana))
        .value
        ?.resumen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Esta semana',
                style: tipografia.tituloTarjeta.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(Rutas.viajes),
              style: TextButton.styleFrom(
                foregroundColor: colores.enlace,
                textStyle: tipografia.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Mis viajes'),
            ),
          ],
        ),
        const SizedBox(height: Espacios.xs),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CifraSemana(
                  valor: resumen?.viajes.toString(),
                  etiqueta: 'Viajes',
                ),
              ),
              const SizedBox(width: Espacios.s),
              Expanded(
                child: _CifraSemana(
                  valor: resumen == null
                      ? null
                      : FormatoViaje.kilometrosEnteros(resumen.distanciaM),
                  etiqueta: 'km',
                ),
              ),
              const SizedBox(width: Espacios.s),
              Expanded(
                child: _CifraSemana(
                  valor: resumen == null
                      ? null
                      : FormatoViaje.duracionCompacta(resumen.duracionS),
                  etiqueta: 'Al volante',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta pequeña de la semana; sin dato (cargando o error), "—".
class _CifraSemana extends StatelessWidget {
  const _CifraSemana({required this.valor, required this.etiqueta});

  final String? valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.micro),
        border: Border.all(color: colores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor ?? '—',
              style: tipografia.puntaje.copyWith(
                color: valor == null
                    ? colores.textoTerciario
                    : colores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            etiqueta,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// El viaje más reciente: hora, distancia, duración y su DriveScore; abre el
/// detalle.
class _UltimoViaje extends ConsumerWidget {
  const _UltimoViaje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viaje = ref.watch(ultimoViajeProvider).value;
    if (viaje == null) return const SizedBox.shrink();
    final colores = context.colores;
    final tipografia = context.tipografia;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Material(
        color: colores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.tarjeta),
          side: BorderSide(color: colores.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Rutas.detalleViaje(viaje.id)),
          child: Padding(
            padding: const EdgeInsets.all(Espacios.m),
            child: Row(
              children: [
                Container(
                  width: Medidas.cajaIconoFila,
                  height: Medidas.cajaIconoFila,
                  decoration: BoxDecoration(
                    color: colores.tintePrimario,
                    borderRadius: BorderRadius.circular(Radios.cajaIcono),
                  ),
                  child: Icon(
                    Icons.route_outlined,
                    size: Medidas.icono,
                    color: colores.primarioOscuro,
                  ),
                ),
                const SizedBox(width: Espacios.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Último viaje · ${FormatoViaje.diaCorto(viaje.salida)} '
                        '${FormatoViaje.hora(viaje.salida)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: Espacios.xxs),
                      Text(
                        '${FormatoViaje.kilometros(viaje.distanciaM)} km · '
                        '${FormatoViaje.duracionCorta(viaje.duracionS)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tipografia.subtitulo.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colores.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (viaje.drivescore case final drivescore?) ...[
                  const SizedBox(width: Espacios.s),
                  _CapsulaPuntaje(drivescore: drivescore),
                ],
                const SizedBox(width: Espacios.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: Medidas.iconoNavegacion,
                  color: colores.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DriveScore del último viaje en el tinte de su calificación.
class _CapsulaPuntaje extends StatelessWidget {
  const _CapsulaPuntaje({required this.drivescore});

  final int drivescore;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final calificacion = Calificacion.de(drivescore);
    final tinte = switch (calificacion) {
      Calificacion.excelente || Calificacion.muyBueno => colores.tintePrimario,
      Calificacion.regular => colores.tinteEventoGiro,
      Calificacion.riesgoso => colores.tinteEventoFrenada,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.xs,
      ),
      decoration: BoxDecoration(
        color: tinte,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Text(
        '$drivescore',
        style: context.tipografia.numeroMetrica.copyWith(
          fontWeight: FontWeight.w700,
          color: colorCalificacion(calificacion, colores),
        ),
      ),
    );
  }
}
