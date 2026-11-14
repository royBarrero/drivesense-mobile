import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/screen_header.dart';
import '../../recorridos/presentation/widgets/load_error.dart';
import '../models/weekly_challenges.dart';
import '../providers/challenges_provider.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/challenge_widgets.dart';

/// Desafíos de la semana (HU-22): cuántos van completados, el tiempo que
/// queda, el bono y una tarjeta por desafío con su avance y recompensa. Se abre
/// desde Inicio. Los desafíos se completan solos al finalizar un viaje (HU-23).
class DesafiosPantalla extends ConsumerWidget {
  const DesafiosPantalla({super.key, this.reloj = DateTime.now});

  /// Para el tiempo restante; se reemplaza en las pruebas.
  final DateTime Function() reloj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final estado = ref.watch(desafiosProvider);
    final semana = estado.value;

    final List<Widget> contenido;
    if (estado.hasError && !estado.isLoading) {
      contenido = [
        Padding(
          padding: const EdgeInsets.only(top: Espacios.xxl),
          child: ErrorCarga(
            error: estado.error!,
            alReintentar: () => ref.invalidate(desafiosProvider),
          ),
        ),
      ];
    } else if (semana == null) {
      contenido = const [
        Padding(
          padding: EdgeInsets.only(top: Espacios.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else {
      contenido = [
        _TarjetaResumen(semana: semana, ahora: reloj()),
        const SizedBox(height: Espacios.l),
        const Etiqueta('Esta semana'),
        for (final desafio in semana.desafios) ...[
          const SizedBox(height: Espacios.s),
          _TarjetaDesafio(desafio: desafio),
        ],
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
              const CabeceraPantalla(titulo: 'Desafíos semanales'),
              const SizedBox(height: Espacios.l),
              ...contenido,
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 de 3 completados", el tiempo restante y la barra.
class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.semana, required this.ahora});

  final DesafiosSemana semana;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final total = semana.desafios.length;
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${semana.completados}',
                style: tipografia.puntaje.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              const SizedBox(width: Espacios.xs),
              Expanded(
                child: Text(
                  'de $total completados',
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.s),
          BarraProgreso(valor: total == 0 ? 0 : semana.completados / total),
          const SizedBox(height: Espacios.s),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: Medidas.iconoPequeno,
                color: colores.textoSecundario,
              ),
              const SizedBox(width: Espacios.xs),
              Text(
                semana.tiempoRestante(ahora),
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.xs),
          _LineaBono(bono: semana.bono),
        ],
      ),
    );
  }
}

/// El bono por completar los 3 desafíos (HU-23): lo que se gana o, ya recibido,
/// "Bono recibido".
class _LineaBono extends StatelessWidget {
  const _LineaBono({required this.bono});

  final BonoSemana bono;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          size: Medidas.iconoPequeno,
          color: bono.recibido
              ? colores.primarioOscuro
              : colores.textoSecundario,
        ),
        const SizedBox(width: Espacios.xs),
        Expanded(
          child: Text(
            bono.recibido
                ? 'Bono recibido · +${bono.puntos} pts'
                : 'Completa los 3 y gana +${bono.puntos} pts de bono',
            style: tipografia.cuerpoPequeno.copyWith(
              color: bono.recibido
                  ? colores.primarioOscuro
                  : colores.textoSecundario,
              fontWeight: bono.recibido ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Un desafío: tipo, nombre, qué hay que hacer, recompensa y avance. Completado,
/// en vez de la recompensa y el avance muestra los puntos recibidos (HU-23).
class _TarjetaDesafio extends StatelessWidget {
  const _TarjetaDesafio({required this.desafio});

  final Desafio desafio;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: decoracionTarjeta(colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CajaDesafio(codigo: desafio.codigo, categoria: desafio.categoria),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiqueta(desafio.tipo.etiqueta),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      desafio.nombre,
                      style: tipografia.cuerpo.copyWith(
                        color: colores.textoPrincipal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      desafio.descripcion,
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              // Completado: los puntos ya se recibieron (abajo), no se ofrecen
              if (!desafio.completado) ...[
                const SizedBox(width: Espacios.s),
                CapsulaPuntos(puntos: desafio.puntos),
              ],
            ],
          ),
          const SizedBox(height: Espacios.m),
          BarraProgreso(valor: desafio.avance),
          const SizedBox(height: Espacios.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  desafio.completado
                      ? '+${desafio.puntos} pts recibidos'
                      : desafio.avanceTexto,
                  style: tipografia.ayuda.copyWith(
                    color: desafio.completado
                        ? colores.primarioOscuro
                        : colores.textoSecundario,
                    fontWeight: desafio.completado ? FontWeight.w700 : null,
                  ),
                ),
              ),
              if (desafio.completado) const CapsulaCompletado(),
            ],
          ),
        ],
      ),
    );
  }
}
