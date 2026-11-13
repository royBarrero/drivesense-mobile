import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/period_chips.dart';
import '../../recorridos/models/trip_score.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/live_alert_capsules.dart';
import '../../recorridos/presentation/widgets/load_error.dart';
import '../../recorridos/presentation/widgets/score_breakdown.dart';
import '../models/period_comparison.dart';
import '../providers/score_history_provider.dart';
import 'widgets/score_screen_parts.dart';
import 'widgets/trend_badge.dart';

/// "Comparar periodos" (HU-20): esta semana o este mes frente al anterior. Se
/// abre desde Mi DriveScore.
class ComparativoPantalla extends ConsumerStatefulWidget {
  const ComparativoPantalla({super.key});

  @override
  ConsumerState<ComparativoPantalla> createState() =>
      _ComparativoPantallaState();
}

class _ComparativoPantallaState extends ConsumerState<ComparativoPantalla> {
  PeriodoComparativo _periodo = PeriodoComparativo.semana;

  void _elegir(PeriodoComparativo periodo) =>
      setState(() => _periodo = periodo);

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estado = ref.watch(comparativoPuntajeProvider(_periodo));
    final comparativo = estado.value;
    final conError = estado.hasError && !estado.isLoading;

    final List<Widget> contenido;
    if (conError) {
      contenido = [
        Padding(
          padding: const EdgeInsets.only(top: Espacios.xxl),
          child: ErrorCarga(
            error: estado.error!,
            alReintentar: () =>
                ref.invalidate(comparativoPuntajeProvider(_periodo)),
          ),
        ),
      ];
    } else if (comparativo == null || estado.isLoading) {
      contenido = const [
        Padding(
          padding: EdgeInsets.only(top: Espacios.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (!comparativo.comparable) {
      contenido = [_SinDatos(comparativo: comparativo, alElegir: _elegir)];
    } else {
      contenido = [
        _TarjetaDriveScore(comparativo: comparativo),
        if (comparativo.masMejoro != null ||
            comparativo.masEmpeoro != null) ...[
          const SizedBox(height: Espacios.m),
          _Destacadas(comparativo: comparativo),
        ],
        if (comparativo.categorias case final categorias?) ...[
          const SizedBox(height: Espacios.m),
          _TarjetaCategorias(
            actuales: comparativo.actual.categorias!,
            cambios: categorias,
          ),
        ],
        const SizedBox(height: Espacios.m),
        _TarjetaCifras(comparativo: comparativo),
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
              const CabeceraPuntaje(titulo: 'Comparar periodos'),
              const SizedBox(height: Espacios.m),
              ChipsPeriodo(
                opciones: PeriodoComparativo.values,
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

/// "▲ 7 pts" sin decimales (los puntajes son enteros).
String _puntos(double diferencia) => '${diferencia.abs().round()}';

/// Un decimal con coma: "1,4".
String _unDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');

/// DriveScore promedio de los dos periodos y su diferencia.
class _TarjetaDriveScore extends StatelessWidget {
  const _TarjetaDriveScore({required this.comparativo});

  final ComparativoPuntaje comparativo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final periodo = comparativo.periodo;
    final actual = comparativo.actual;
    final anterior = comparativo.anterior;
    final cambio = comparativo.drivescore;

    Widget columna({
      required String titulo,
      required ResumenPeriodoComparativo resumen,
      required TextStyle estiloNumero,
      required Color colorNumero,
    }) {
      final calificacion = resumen.calificacion;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          Text(
            '${resumen.drivescore}',
            style: estiloNumero.copyWith(color: colorNumero),
          ),
          if (calificacion != null)
            Text(
              calificacion.texto,
              style: tipografia.cuerpo.copyWith(
                color: colorCalificacion(calificacion, colores),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Etiqueta('DriveScore promedio')),
              if (cambio != null)
                CapsulaTendencia(tendencia: cambio.diferencia.round()),
            ],
          ),
          const SizedBox(height: Espacios.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: columna(
                  titulo: periodo.actual,
                  resumen: actual,
                  estiloNumero: tipografia.telemetria,
                  colorNumero: colores.textoPrincipal,
                ),
              ),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: columna(
                  titulo: periodo.anterior,
                  resumen: anterior,
                  estiloNumero: tipografia.puntaje,
                  colorNumero: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Lo que más mejoró" y "Lo que más empeoró"; si falta una, la otra ocupa
/// todo el ancho.
class _Destacadas extends StatelessWidget {
  const _Destacadas({required this.comparativo});

  final ComparativoPuntaje comparativo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final mejoro = comparativo.masMejoro;
    final empeoro = comparativo.masEmpeoro;
    final cambios = comparativo.categorias!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mejoro != null)
            Expanded(
              child: _Destacada(
                titulo: 'Lo que más mejoró',
                categoria: mejoro,
                diferencia: cambios[mejoro]!.diferencia,
                tinte: colores.tintePrimario,
                colorCambio: colores.primarioOscuro,
              ),
            ),
          if (mejoro != null && empeoro != null)
            const SizedBox(width: Espacios.m),
          if (empeoro != null)
            Expanded(
              child: _Destacada(
                titulo: 'Lo que más empeoró',
                categoria: empeoro,
                diferencia: cambios[empeoro]!.diferencia,
                tinte: colores.tintePeligro,
                colorCambio: colores.textoPeligro,
              ),
            ),
        ],
      ),
    );
  }
}

class _Destacada extends StatelessWidget {
  const _Destacada({
    required this.titulo,
    required this.categoria,
    required this.diferencia,
    required this.tinte,
    required this.colorCambio,
  });

  final String titulo;
  final CategoriaPuntaje categoria;
  final double diferencia;
  final Color tinte;
  final Color colorCambio;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estilo = EstiloEvento.de(categoria.tipo, colores);
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: BoxDecoration(
        color: tinte,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          const SizedBox(height: Espacios.s),
          Row(
            children: [
              Container(
                width: Medidas.cajaIcono,
                height: Medidas.cajaIcono,
                decoration: BoxDecoration(
                  color: estilo.tinte,
                  borderRadius: BorderRadius.circular(Radios.cajaIcono),
                ),
                child: Icon(
                  estilo.icono,
                  size: Medidas.icono,
                  color: estilo.texto,
                ),
              ),
              const SizedBox(width: Espacios.s),
              Expanded(
                child: Text(
                  categoria.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tipografia.subtitulo.copyWith(
                    color: colores.textoPrincipal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.xs),
          Text(
            '${diferencia > 0 ? '▲' : '▼'} ${_puntos(diferencia)} pts',
            style: tipografia.cuerpo.copyWith(
              color: colorCambio,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Puntaje actual de cada categoría con su cambio, como en Mi DriveScore.
class _TarjetaCategorias extends StatelessWidget {
  const _TarjetaCategorias({required this.actuales, required this.cambios});

  final Map<CategoriaPuntaje, int> actuales;
  final Map<CategoriaPuntaje, CambioPuntaje> cambios;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(context.colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Etiqueta('Por categoría'),
          const SizedBox(height: Espacios.m),
          for (final (i, categoria) in CategoriaPuntaje.values.indexed)
            if ((actuales[categoria], cambios[categoria]) case (
              final puntaje?,
              final cambio?,
            )) ...[
              if (i > 0) const SizedBox(height: Espacios.s),
              FilaCategoria(
                categoria: categoria,
                puntaje: puntaje,
                extra: DiferenciaCategoria(
                  diferencia: cambio.diferencia.round(),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// Viajes, km y eventos cada 10 km de los dos periodos.
class _TarjetaCifras extends StatelessWidget {
  const _TarjetaCifras({required this.comparativo});

  final ComparativoPuntaje comparativo;

  @override
  Widget build(BuildContext context) {
    final actual = comparativo.actual;
    final anterior = comparativo.anterior;
    final eventos = comparativo.eventosPor10Km;
    final porDistancia = (actual.eventosPor10Km, anterior.eventosPor10Km);
    final viajes = comparativo.viajes ?? 0;
    final distancia = comparativo.distanciaM ?? 0;

    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(context.colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Etiqueta('Actividad'),
          const SizedBox(height: Espacios.m),
          _FilaCifra(
            nombre: 'Viajes',
            actual: '${actual.viajes}',
            anterior: '${anterior.viajes}',
            periodoAnterior: comparativo.periodo.anterior,
            cambio: CambioCifra(
              diferencia: viajes.toDouble(),
              texto: '${viajes.abs()}',
            ),
          ),
          const SizedBox(height: Espacios.m),
          _FilaCifra(
            nombre: 'Kilómetros',
            actual: FormatoViaje.kilometros(actual.distanciaM),
            anterior: FormatoViaje.kilometros(anterior.distanciaM),
            periodoAnterior: comparativo.periodo.anterior,
            cambio: CambioCifra(
              diferencia: distancia,
              texto: FormatoViaje.kilometros(distancia.abs()),
            ),
          ),
          if (porDistancia case (final hoy?, final antes?)) ...[
            const SizedBox(height: Espacios.m),
            _FilaCifra(
              nombre: 'Eventos cada 10 km',
              actual: _unDecimal(hoy),
              anterior: _unDecimal(antes),
              periodoAnterior: comparativo.periodo.anterior,
              cambio: eventos == null
                  ? null
                  : CambioCifra(
                      diferencia: eventos.diferencia,
                      texto: _unDecimal(eventos.diferencia.abs()),
                      mejora: switch (eventos.resultado) {
                        ResultadoCambio.mejoro => true,
                        ResultadoCambio.empeoro => false,
                        ResultadoCambio.igual => null,
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaCifra extends StatelessWidget {
  const _FilaCifra({
    required this.nombre,
    required this.actual,
    required this.anterior,
    required this.periodoAnterior,
    this.cambio,
  });

  final String nombre;
  final String actual;
  final String anterior;
  final String periodoAnterior;
  final Widget? cambio;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              Text(
                '$periodoAnterior: $anterior',
                style: tipografia.ayuda.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        Text(
          actual,
          style: tipografia.numeroMetrica.copyWith(
            color: colores.textoPrincipal,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: Espacios.m),
        cambio ?? const SizedBox(width: Medidas.cajaIcono),
      ],
    );
  }
}

/// Algún periodo no llega al mínimo: aviso con cuántos viajes lleva cada uno y
/// botón para ver el otro periodo.
class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.comparativo, required this.alElegir});

  final ComparativoPuntaje comparativo;
  final ValueChanged<PeriodoComparativo> alElegir;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final periodo = comparativo.periodo;
    final minimo = comparativo.minimoViajes;
    return Container(
      padding: const EdgeInsets.all(Espacios.xl),
      decoration: decoracionTarjeta(colores),
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
              Icons.compare_arrows_rounded,
              size: Medidas.iconoEstado,
              color: colores.primarioOscuro,
            ),
          ),
          const SizedBox(height: Espacios.m),
          Text(
            'No hay datos para comparar',
            textAlign: TextAlign.center,
            style: tipografia.subtituloGrande.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            'Necesitas al menos $minimo '
            '${minimo == 1 ? 'viaje' : 'viajes'} en cada periodo.',
            textAlign: TextAlign.center,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            '${periodo.actual}: ${comparativo.actual.viajes} · '
            '${periodo.anterior}: ${comparativo.anterior.viajes}',
            textAlign: TextAlign.center,
            style: tipografia.cuerpoPequeno.copyWith(
              color: colores.textoSecundario,
            ),
          ),
          const SizedBox(height: Espacios.l),
          for (final otro in PeriodoComparativo.values)
            if (otro != periodo)
              OutlinedButton(
                onPressed: () => alElegir(otro),
                child: Text('Ver ${otro.texto.toLowerCase()}'),
              ),
        ],
      ),
    );
  }
}
