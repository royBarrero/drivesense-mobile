import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../../recorridos/presentation/widgets/live_alert_capsules.dart';
import '../../models/recommendation.dart';

/// Tinte, color e ícono de la caja de un consejo: los del tipo de evento
/// (`EstiloEvento`) o, en el mensaje positivo, los del color primario.
(Color, Color, IconData) estiloConsejo(
  Recomendacion recomendacion,
  ColoresDriveSense colores,
) => switch (recomendacion.tipo) {
  null => (
    colores.tintePrimario,
    colores.primarioOscuro,
    Icons.verified_outlined,
  ),
  final tipo => switch (EstiloEvento.de(tipo, colores)) {
    final estilo => (estilo.tinte, estilo.texto, estilo.icono),
  },
};

/// Tarjeta "Consejo" (HU-18): caja con el ícono del tipo de evento (o la del
/// mensaje positivo), título y texto. Va en el resumen, el detalle e Inicio.
class TarjetaConsejo extends StatelessWidget {
  const TarjetaConsejo({
    super.key,
    required this.recomendacion,
    this.alPresionar,
  });

  final Recomendacion recomendacion;

  /// Con valor, la tarjeta se puede tocar y muestra el chevron (Inicio).
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final (tinte, color, icono) = estiloConsejo(recomendacion, colores);
    final alPresionar = this.alPresionar;

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
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(Espacios.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: Medidas.cajaIconoFila,
                  height: Medidas.cajaIconoFila,
                  decoration: BoxDecoration(
                    color: tinte,
                    borderRadius: BorderRadius.circular(Radios.cajaIcono),
                  ),
                  child: Icon(icono, size: Medidas.icono, color: color),
                ),
                const SizedBox(width: Espacios.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: Espacios.xs,
                        runSpacing: Espacios.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Etiqueta('Consejo'),
                          if (recomendacion.generadaPorIa) const CapsulaIA(),
                        ],
                      ),
                      const SizedBox(height: Espacios.xxs),
                      Text(
                        recomendacion.titulo,
                        style: tipografia.subtitulo.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colores.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: Espacios.xxs),
                      Text(
                        recomendacion.texto,
                        style: tipografia.cuerpo.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alPresionar != null) ...[
                  const SizedBox(width: Espacios.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: Medidas.iconoNavegacion,
                    color: colores.textoSecundario,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cápsula "Con IA": el consejo lo redactó la IA con los datos del viaje
/// (docs/diseno.md). Tinte y texto de confort, un acento distinto del de los
/// tipos de evento de la caja del ícono.
class CapsulaIA extends StatelessWidget {
  const CapsulaIA({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.xs,
        vertical: Espacios.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: colores.tinteConfort,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: Medidas.iconoMinimo,
            color: colores.textoEventoAceleracion,
          ),
          const SizedBox(width: Espacios.xxs),
          Text(
            'CON IA',
            style: context.tipografia.etiqueta.copyWith(
              color: colores.textoEventoAceleracion,
            ),
          ),
        ],
      ),
    );
  }
}
