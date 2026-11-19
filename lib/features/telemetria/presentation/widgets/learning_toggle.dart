import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../../navegacion/providers/copilot_provider.dart';
import '../../providers/learning_mode_provider.dart';

/// Fila "Modo aprendizaje" con su interruptor (HU-31): en el Copiloto antes de
/// iniciar, en Perfil y en la tarjeta del viaje libre.
class InterruptorAprendizaje extends ConsumerWidget {
  const InterruptorAprendizaje({super.key});

  static const textoAyuda =
      'Consejos breves por voz después de cada evento de riesgo.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final activo = ref.watch(modoAprendizajeProvider).value ?? false;
    return Row(
      children: [
        Container(
          width: Medidas.cajaIcono,
          height: Medidas.cajaIcono,
          decoration: BoxDecoration(
            color: colores.tinteConfort,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(
            Icons.school_outlined,
            size: Medidas.icono,
            color: colores.textoEventoAceleracion,
          ),
        ),
        const SizedBox(width: Espacios.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modo aprendizaje',
                style: tipografia.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colores.textoPrincipal,
                ),
              ),
              Text(
                textoAyuda,
                style: tipografia.ayuda.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espacios.xs),
        Switch(
          value: activo,
          onChanged: (valor) =>
              ref.read(modoAprendizajeProvider.notifier).cambiar(valor),
        ),
      ],
    );
  }
}

/// Tarjeta del viaje libre (HU-31): el interruptor y, si está activo, el
/// silencio de la voz para este viaje.
class TarjetaAprendizaje extends ConsumerWidget {
  const TarjetaAprendizaje({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final activo = ref.watch(modoAprendizajeProvider).value ?? false;
    final silenciado = ref.watch(
      copilotoProvider.select((estado) => estado?.silenciado ?? false),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InterruptorAprendizaje(),
          if (activo) ...[
            const SizedBox(height: Espacios.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(copilotoProvider.notifier).silenciar(!silenciado),
                icon: Icon(
                  silenciado
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: Medidas.icono,
                ),
                label: Text(
                  silenciado ? 'Voz silenciada en este viaje' : 'Silenciar voz',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
