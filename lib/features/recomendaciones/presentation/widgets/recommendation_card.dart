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
                      const Etiqueta('Consejo'),
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
