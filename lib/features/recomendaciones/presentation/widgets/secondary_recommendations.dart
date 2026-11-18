import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../models/recommendation.dart';
import 'recommendation_card.dart';

/// Recomendaciones secundarias (HU-19): una tarjeta "También puedes mejorar"
/// con una fila compacta por consejo. Va debajo de [TarjetaConsejo] en el
/// resumen y en el detalle; Inicio muestra solo la principal.
class ConsejosSecundarios extends StatelessWidget {
  const ConsejosSecundarios({super.key, required this.recomendaciones});

  final List<Recomendacion> recomendaciones;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap: en pantallas angostas la cápsula baja a otra línea
          Wrap(
            spacing: Espacios.xs,
            runSpacing: Espacios.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Etiqueta('También puedes mejorar'),
              if (recomendaciones.any((r) => r.generadaPorIa))
                const CapsulaIA(),
            ],
          ),
          for (final consejo in recomendaciones) ...[
            const SizedBox(height: Espacios.s),
            _FilaConsejo(recomendacion: consejo),
          ],
        ],
      ),
    );
  }
}

class _FilaConsejo extends StatelessWidget {
  const _FilaConsejo({required this.recomendacion});

  final Recomendacion recomendacion;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final (tinte, color, icono) = estiloConsejo(recomendacion, colores);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: Medidas.cajaIcono,
          height: Medidas.cajaIcono,
          decoration: BoxDecoration(
            color: tinte,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(icono, size: Medidas.icono, color: color),
        ),
        const SizedBox(width: Espacios.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recomendacion.titulo,
                style: tipografia.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colores.textoPrincipal,
                ),
              ),
              const SizedBox(height: Espacios.xxs),
              Text(
                recomendacion.texto,
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
