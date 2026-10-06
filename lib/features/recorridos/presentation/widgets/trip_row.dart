import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../models/trip_history.dart';
import '../trip_format.dart';

/// Fila de un viaje del historial (docs/diseno.md, 7.1): caja de ícono tintada,
/// franja horaria, duración y máxima, y la distancia destacada.
class FilaViaje extends StatelessWidget {
  const FilaViaje({
    super.key,
    required this.recorrido,
    required this.indice,
    required this.alPresionar,
  });

  final RecorridoHistorial recorrido;

  /// Posición en la lista: el color de la caja de ícono rota con ella.
  final int indice;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final (tinte, colorIcono) = switch (indice % 3) {
      0 => (colores.tintePrimario, colores.primarioOscuro),
      1 => (colores.tinteSecundario, colores.secundario),
      _ => (colores.tinteConfort, colores.confort),
    };

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
              children: [
                Container(
                  width: Medidas.cajaIconoFila,
                  height: Medidas.cajaIconoFila,
                  decoration: BoxDecoration(
                    color: tinte,
                    borderRadius: BorderRadius.circular(Radios.cajaIcono),
                  ),
                  child: Icon(
                    Icons.route_outlined,
                    size: Medidas.icono,
                    color: colorIcono,
                  ),
                ),
                const SizedBox(width: Espacios.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${FormatoViaje.hora(recorrido.salida)} – '
                        '${FormatoViaje.hora(recorrido.llegada)}',
                        style: tipografia.subtitulo.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                      Text(
                        '${FormatoViaje.duracionCorta(recorrido.duracionS)} · '
                        'máx. ${FormatoViaje.velocidad(recorrido.velocidadMaximaKmh)} km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Espacios.xs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: FormatoViaje.kilometros(recorrido.distanciaM),
                        style: tipografia.numeroLista.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                      TextSpan(
                        text: ' km',
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Espacios.xs),
                Icon(
                  Icons.chevron_right,
                  size: Medidas.icono,
                  color: colores.textoTerciario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
