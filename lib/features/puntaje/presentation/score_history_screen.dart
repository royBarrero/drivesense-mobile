import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/period_chips.dart';
import '../../recorridos/models/trip_score.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/load_error.dart';
import '../../recorridos/presentation/widgets/score_breakdown.dart';
import '../models/score_history.dart';
import '../providers/score_history_provider.dart';
import 'widgets/score_chart.dart';
import 'widgets/trend_badge.dart';

/// "Mi DriveScore" (HU-17, diseño 2): promedio del periodo con su tendencia y
/// gráfico, promedio por categoría y el mejor y el peor viaje.
class MiDriveScorePantalla extends ConsumerStatefulWidget {
  const MiDriveScorePantalla({super.key});

  @override
  ConsumerState<MiDriveScorePantalla> createState() =>
      _MiDriveScorePantallaState();
}

class _MiDriveScorePantallaState extends ConsumerState<MiDriveScorePantalla> {
  PeriodoPuntaje _periodo = PeriodoPuntaje.dias7;

  void _elegir(PeriodoPuntaje periodo) => setState(() => _periodo = periodo);

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estado = ref.watch(historicoPuntajeProvider(_periodo));
    final historico = estado.value;
    final conError = estado.hasError && !estado.isLoading;

    final List<Widget> contenido;
    if (conError) {
      contenido = [
        Padding(
          padding: const EdgeInsets.only(top: Espacios.xxl),
          child: ErrorCarga(
            error: estado.error!,
            alReintentar: () =>
                ref.invalidate(historicoPuntajeProvider(_periodo)),
          ),
        ),
      ];
    } else if (historico == null || estado.isLoading) {
      contenido = const [
        Padding(
          padding: EdgeInsets.only(top: Espacios.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (historico.viajes == 0) {
      contenido = [_PeriodoVacio(periodo: _periodo, alElegir: _elegir)];
    } else {
      contenido = [
        _TarjetaPromedio(historico: historico),
        if (historico.categorias case final categorias?) ...[
          const SizedBox(height: Espacios.m),
          _TarjetaCategorias(categorias: categorias),
        ],
        const SizedBox(height: Espacios.m),
        _ViajesDestacados(mejor: historico.mejor, peor: historico.peor),
      ];
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.fondo,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Espacios.l,
              Espacios.m,
              Espacios.l,
              MediaQuery.paddingOf(context).bottom + Espacios.l,
            ),
            children: [
              Row(
                children: [
                  const _BotonVolver(),
                  const SizedBox(width: Espacios.m),
                  Expanded(
                    child: Text(
                      'Mi DriveScore',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tipografia.titulo.copyWith(
                        color: colores.textoPrincipal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espacios.m),
              ChipsPeriodo(
                opciones: PeriodoPuntaje.values,
                texto: (periodo) => periodo.texto,
                seleccionado: _periodo,
                alSeleccionar: _elegir,
              ),
              const SizedBox(height: Espacios.m),
              ...contenido,
            ],
          ),
        ),
      ),
    );
  }
}

/// Volver en caja de 44 blanca; sin pantalla anterior, a Inicio.
class _BotonVolver extends StatelessWidget {
  const _BotonVolver();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.campo),
        side: BorderSide(color: colores.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.campo),
        onTap: () =>
            context.canPop() ? context.pop() : context.go(Rutas.inicio),
        child: SizedBox.square(
          dimension: Medidas.botonVolver,
          child: Icon(
            Icons.chevron_left_rounded,
            size: Medidas.iconoNavegacion,
            color: colores.textoPrincipal,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _tarjeta(ColoresDriveSense colores) => BoxDecoration(
  color: colores.superficie,
  borderRadius: BorderRadius.circular(Radios.tarjeta),
  border: Border.all(color: colores.borde),
  boxShadow: colores.sombraTarjeta,
);

/// Promedio, calificación, cantidad de viajes, tendencia y el gráfico.
class _TarjetaPromedio extends StatelessWidget {
  const _TarjetaPromedio({required this.historico});

  final HistoricoPuntaje historico;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final viajes = historico.viajes;
    final calificacion = historico.calificacion;
    final tendencia = historico.tendencia;

    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: _tarjeta(colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promedio · $viajes ${viajes == 1 ? 'viaje' : 'viajes'}',
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${historico.promedio}',
                style: tipografia.telemetria.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              const SizedBox(width: Espacios.s),
              Expanded(
                child: calificacion == null
                    ? const SizedBox.shrink()
                    : Text(
                        calificacion.texto,
                        style: tipografia.tituloTarjeta.copyWith(
                          color: colorCalificacion(calificacion, colores),
                        ),
                      ),
              ),
              if (tendencia != null) CapsulaTendencia(tendencia: tendencia),
            ],
          ),
          const SizedBox(height: Espacios.m),
          GraficoDriveScore(
            puntos: historico.puntos,
            desde: historico.desde,
            hasta: historico.hasta,
          ),
        ],
      ),
    );
  }
}

/// Promedio de cada categoría con su cambio frente al periodo anterior.
class _TarjetaCategorias extends StatelessWidget {
  const _TarjetaCategorias({required this.categorias});

  final Map<CategoriaPuntaje, PromedioCategoria> categorias;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: _tarjeta(context.colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Etiqueta('Promedio por categoría'),
          const SizedBox(height: Espacios.m),
          for (final (i, categoria) in CategoriaPuntaje.values.indexed)
            if (categorias[categoria] case final promedio?) ...[
              if (i > 0) const SizedBox(height: Espacios.s),
              FilaCategoria(
                categoria: categoria,
                puntaje: promedio.promedio,
                // Sin periodo anterior no hay con qué comparar: el espacio
                // queda vacío para que las barras sigan alineadas
                extra: switch (promedio.diferencia) {
                  final diferencia? => DiferenciaCategoria(
                    diferencia: diferencia,
                  ),
                  null => const SizedBox(width: Medidas.cajaIcono),
                },
              ),
            ],
        ],
      ),
    );
  }
}

/// "Mejor viaje" y "Viaje más bajo"; abren su detalle.
class _ViajesDestacados extends StatelessWidget {
  const _ViajesDestacados({required this.mejor, required this.peor});

  final ViajeDestacado? mejor;
  final ViajeDestacado? peor;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final mejor = this.mejor;
    final peor = this.peor;
    if (mejor == null) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ViajeDestacado(
              titulo: 'Mejor viaje',
              viaje: mejor,
              tinte: colores.tintePrimario,
            ),
          ),
          const SizedBox(width: Espacios.m),
          // Con un solo viaje no hay "más bajo"
          Expanded(
            child: peor == null
                ? const SizedBox.shrink()
                : _ViajeDestacado(
                    titulo: 'Viaje más bajo',
                    viaje: peor,
                    tinte: colores.tintePeligro,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViajeDestacado extends StatelessWidget {
  const _ViajeDestacado({
    required this.titulo,
    required this.viaje,
    required this.tinte,
  });

  final String titulo;
  final ViajeDestacado viaje;
  final Color tinte;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Material(
      color: tinte,
      borderRadius: BorderRadius.circular(Radios.tarjeta),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        onTap: () => context.push(Rutas.detalleViaje(viaje.id)),
        child: Padding(
          padding: const EdgeInsets.all(Espacios.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
              const SizedBox(height: Espacios.xxs),
              Text(
                '${viaje.drivescore}',
                style: tipografia.puntaje.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              const SizedBox(height: Espacios.xxs),
              Text(
                '${FormatoViaje.fechaCorta(viaje.fecha)} · '
                '${FormatoViaje.kilometros(viaje.distanciaM)} km',
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Periodo sin viajes: aviso y botones para ver los otros periodos.
class _PeriodoVacio extends StatelessWidget {
  const _PeriodoVacio({required this.periodo, required this.alElegir});

  final PeriodoPuntaje periodo;
  final ValueChanged<PeriodoPuntaje> alElegir;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      padding: const EdgeInsets.all(Espacios.xl),
      decoration: _tarjeta(colores),
      child: Column(
        children: [
          Container(
            width: Medidas.circuloEstado,
            height: Medidas.circuloEstado,
            decoration: BoxDecoration(
              color: colores.tintePrimario,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              size: Medidas.iconoEstado,
              color: colores.primarioOscuro,
            ),
          ),
          const SizedBox(height: Espacios.m),
          Text(
            'No tienes viajes en los últimos ${periodo.texto}',
            textAlign: TextAlign.center,
            style: tipografia.subtituloGrande.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            'Prueba con otro periodo.',
            textAlign: TextAlign.center,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          const SizedBox(height: Espacios.l),
          Wrap(
            spacing: Espacios.xs,
            runSpacing: Espacios.xs,
            alignment: WrapAlignment.center,
            children: [
              for (final otro in PeriodoPuntaje.values)
                if (otro != periodo)
                  OutlinedButton(
                    onPressed: () => alElegir(otro),
                    child: Text('Ver ${otro.texto}'),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
