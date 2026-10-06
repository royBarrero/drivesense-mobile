import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../telemetria/models/event_detector.dart';
import '../../models/trip_score.dart';
import 'live_alert_capsules.dart';

/// Desglose del DriveScore (HU-16): una fila por categoría con la caja de
/// ícono tintada, el nombre, la barra y el puntaje, en los colores del tipo de
/// evento (HU-14). Con [eventosPorTipo], bajo el nombre va cuántos hubo.
class DesgloseCategorias extends StatelessWidget {
  const DesgloseCategorias({
    super.key,
    required this.puntaje,
    this.eventosPorTipo,
  });

  final PuntajeViaje puntaje;
  final Map<TipoEvento, int>? eventosPorTipo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, categoria) in CategoriaPuntaje.values.indexed) ...[
          if (i > 0) const SizedBox(height: Espacios.s),
          FilaCategoria(
            categoria: categoria,
            puntaje: puntaje.de(categoria),
            detalle: switch (eventosPorTipo?[categoria.tipo]) {
              final cantidad? => categoria.eventos(cantidad),
              null => null,
            },
          ),
        ],
      ],
    );
  }
}

/// Fila de una categoría: caja de ícono tintada, nombre (con [detalle] debajo),
/// barra y puntaje; [extra] va al final (la diferencia en Mi DriveScore, HU-17).
class FilaCategoria extends StatelessWidget {
  const FilaCategoria({
    super.key,
    required this.categoria,
    required this.puntaje,
    this.detalle,
    this.extra,
  });

  final CategoriaPuntaje categoria;
  final int puntaje;
  final String? detalle;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estilo = EstiloEvento.de(categoria.tipo, colores);
    final detalle = this.detalle;

    return Row(
      children: [
        Container(
          width: Medidas.cajaIcono,
          height: Medidas.cajaIcono,
          decoration: BoxDecoration(
            color: estilo.tinte,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(estilo.icono, size: Medidas.icono, color: estilo.texto),
        ),
        const SizedBox(width: Espacios.s),
        Expanded(
          // Con [extra] la barra se acorta para que el nombre quepa entero
          flex: extra == null ? 5 : 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoria.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              if (detalle != null)
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tipografia.ayuda.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: Espacios.xs),
        Expanded(
          flex: extra == null ? 6 : 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radios.pildora),
            child: LinearProgressIndicator(
              value: puntaje / 100,
              minHeight: Medidas.altoBarra,
              backgroundColor: colores.carril,
              color: estilo.texto,
            ),
          ),
        ),
        SizedBox(
          width: Medidas.cajaIcono + Espacios.xs,
          child: Text(
            '$puntaje',
            textAlign: TextAlign.end,
            style: tipografia.numeroMetrica.copyWith(
              color: colores.textoPrincipal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?extra,
      ],
    );
  }
}

/// Color de la calificación sobre fondo claro: Excelente y Muy bueno
/// `primarioOscuro`, Regular `textoEventoGiro`, Riesgoso `textoEventoFrenada`.
Color colorCalificacion(Calificacion calificacion, ColoresDriveSense colores) =>
    switch (calificacion) {
      Calificacion.excelente || Calificacion.muyBueno => colores.primarioOscuro,
      Calificacion.regular => colores.textoEventoGiro,
      Calificacion.riesgoso => colores.textoEventoFrenada,
    };

/// Texto junto a la calificación (HU-16): "Lo que más restó: frenadas" o, si el
/// viaje no tuvo eventos, un mensaje positivo. `null` si hubo eventos pero
/// ninguna categoría bajó de 100 (p. ej. un exceso muy breve en un viaje largo).
String? textoMasResto(PuntajeViaje puntaje, {required bool sinEventos}) {
  if (sinEventos) return 'Sin eventos de riesgo. ¡Sigue así!';
  final categoria = puntaje.masResto;
  return categoria == null ? null : 'Lo que más restó: ${categoria.enTexto}';
}
