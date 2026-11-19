import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../models/route_plan.dart';
import '../route_format.dart';

/// Abre la hoja con los pasos de [ruta].
Future<void> mostrarPasosRuta(BuildContext context, RutaPlaneada ruta) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => HojaPasosRuta(ruta: ruta),
    );

/// Hoja arrastrable "Pasos de la ruta": una fila por indicación.
class HojaPasosRuta extends StatelessWidget {
  const HojaPasosRuta({super.key, required this.ruta});

  final RutaPlaneada ruta;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, desplazamiento) => ListView.separated(
        controller: desplazamiento,
        padding: EdgeInsets.fromLTRB(
          Espacios.l,
          0,
          Espacios.l,
          Espacios.l + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: ruta.pasos.length + 1,
        separatorBuilder: (_, indice) => indice == 0
            ? const SizedBox(height: Espacios.m)
            : Divider(height: Espacios.l, color: colores.borde),
        itemBuilder: (context, indice) {
          if (indice == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasos de la ruta',
                  style: tipografia.subtituloGrande.copyWith(
                    color: colores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: Espacios.xxs),
                Text(
                  '${FormatoRuta.resumen(ruta)} · en auto',
                  style: tipografia.cuerpoPequeno.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
              ],
            );
          }
          return _FilaPaso(paso: ruta.pasos[indice - 1]);
        },
      ),
    );
  }
}

class _FilaPaso extends StatelessWidget {
  const _FilaPaso({required this.paso});

  final PasoRuta paso;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final llegada = paso.tipo == TipoPaso.llegada;
    return Row(
      children: [
        Container(
          width: Medidas.cajaIconoFila,
          height: Medidas.cajaIconoFila,
          decoration: BoxDecoration(
            color: llegada ? colores.encabezadoFondo : colores.superficieAlt,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(
            FormatoRuta.icono(paso.tipo),
            size: Medidas.icono,
            color: llegada ? colores.encabezadoAcento : colores.textoPrincipal,
          ),
        ),
        const SizedBox(width: Espacios.m),
        Expanded(
          child: Text(
            paso.instruccion,
            style: tipografia.cuerpo.copyWith(color: colores.textoPrincipal),
          ),
        ),
        // La llegada no tiene tramo
        if (paso.distanciaM > 0) ...[
          const SizedBox(width: Espacios.s),
          Text(
            FormatoRuta.distancia(paso.distanciaM),
            style: tipografia.numeroMetrica.copyWith(
              fontWeight: FontWeight.w700,
              color: colores.textoPrincipal,
            ),
          ),
        ],
      ],
    );
  }
}
