import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../models/progress.dart';
import '../../providers/progress_provider.dart';
import 'achievement_widgets.dart';

/// Nivel del conductor en Perfil (HU-21): nivel, puntos, avance al siguiente y
/// acceso a los logros.
class TarjetaNivel extends ConsumerWidget {
  const TarjetaNivel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estado = ref.watch(progresoProvider);
    final progreso = estado.value;

    final Widget contenido;
    if (estado.hasError && !estado.isLoading) {
      final error = estado.error;
      contenido = Row(
        children: [
          Expanded(
            child: Text(
              error is ErrorApi ? error.mensaje : 'No se pudo cargar tu nivel',
              style: tipografia.cuerpoPequeno.copyWith(
                color: colores.textoSecundario,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(progresoProvider),
            child: const Text('Reintentar'),
          ),
        ],
      );
    } else if (progreso == null) {
      contenido = const SizedBox(
        height: Medidas.cajaIconoFila,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      contenido = _Contenido(progreso: progreso);
    }

    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(colores),
      child: contenido,
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.progreso});

  final ProgresoConductor progreso;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final siguiente = progreso.siguienteNivel;
    final total = progreso.logros.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: Medidas.cajaIconoFila,
              height: Medidas.cajaIconoFila,
              decoration: BoxDecoration(
                color: colores.tintePrimario,
                borderRadius: BorderRadius.circular(Radios.cajaIcono),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: Medidas.icono,
                color: colores.primarioOscuro,
              ),
            ),
            const SizedBox(width: Espacios.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Etiqueta('Nivel ${progreso.nivel.numero}'),
                  const SizedBox(height: Espacios.xxs),
                  Text(
                    progreso.nivel.nombre,
                    style: tipografia.subtituloGrande.copyWith(
                      color: colores.textoPrincipal,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${progreso.puntos} pts',
              style: tipografia.numeroMetrica.copyWith(
                color: colores.textoPrincipal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacios.m),
        BarraProgreso(valor: progreso.avance),
        const SizedBox(height: Espacios.xs),
        Text(
          siguiente == null
              ? 'Alcanzaste el nivel máximo'
              : 'Te faltan ${siguiente.puntos - progreso.puntos} pts para '
                    '${siguiente.nombre}',
          style: tipografia.cuerpoPequeno.copyWith(
            color: colores.textoSecundario,
          ),
        ),
        Divider(height: Espacios.xl, color: colores.bordeFuerte),
        InkWell(
          borderRadius: BorderRadius.circular(Radios.campo),
          onTap: () => context.push(Rutas.logros),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Espacios.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Logros',
                    style: tipografia.cuerpo.copyWith(
                      color: colores.textoPrincipal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${progreso.desbloqueados} de $total',
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: Medidas.iconoNavegacion,
                  color: colores.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
