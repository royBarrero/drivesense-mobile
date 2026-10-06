import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Colores y símbolo de un cambio de puntaje: ▲ mejora, ▼ empeora, = igual.
({String simbolo, Color texto, Color tinte}) _estiloCambio(
  int cambio,
  ColoresDriveSense colores,
) => switch (cambio) {
  > 0 => (
    simbolo: '▲',
    texto: colores.primarioOscuro,
    tinte: colores.tintePrimario,
  ),
  < 0 => (
    simbolo: '▼',
    texto: colores.textoPeligro,
    tinte: colores.tintePeligro,
  ),
  _ => (
    simbolo: '=',
    texto: colores.textoSecundario,
    tinte: colores.superficieAlt,
  ),
};

/// Colores de un cambio sobre el encabezado oscuro de Inicio.
({String simbolo, Color texto, Color tinte}) _estiloCambioOscuro(
  int cambio,
  ColoresDriveSense colores,
) => switch (cambio) {
  > 0 => (
    simbolo: '▲',
    texto: colores.encabezadoAcento,
    tinte: colores.acentoOscuroTenue,
  ),
  < 0 => (
    simbolo: '▼',
    texto: colores.eventoFrenada,
    tinte: colores.encabezadoSuperficie,
  ),
  _ => (
    simbolo: '=',
    texto: colores.encabezadoTextoSecundario,
    tinte: colores.encabezadoSuperficie,
  ),
};

/// Cápsula de la tendencia frente al periodo anterior (HU-17): "▲ 4 pts" y,
/// con [sufijo], "▲ 4 pts en 7 días". [sobreOscuro]: para el encabezado de
/// Inicio.
class CapsulaTendencia extends StatelessWidget {
  const CapsulaTendencia({
    super.key,
    required this.tendencia,
    this.sufijo,
    this.sobreOscuro = false,
  });

  final int tendencia;
  final String? sufijo;
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    final estilo = sobreOscuro
        ? _estiloCambioOscuro(tendencia, context.colores)
        : _estiloCambio(tendencia, context.colores);
    final sufijo = this.sufijo;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sobreOscuro ? Espacios.s : Espacios.xs + Espacios.xxs,
        vertical: sobreOscuro ? Espacios.xs - 2 : Espacios.xxs,
      ),
      decoration: BoxDecoration(
        color: estilo.tinte,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Text(
        '${estilo.simbolo} ${tendencia.abs()} pts'
        '${sufijo == null ? '' : ' $sufijo'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (sobreOscuro ? context.tipografia.cuerpo : context.tipografia.ayuda)
                .copyWith(color: estilo.texto, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Cambio de una categoría al final de su fila: "▲ 5", "▼ 2" o "=".
class DiferenciaCategoria extends StatelessWidget {
  const DiferenciaCategoria({super.key, required this.diferencia});

  final int diferencia;

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloCambio(diferencia, context.colores);
    return SizedBox(
      width: Medidas.cajaIcono,
      child: Text(
        diferencia == 0
            ? estilo.simbolo
            : '${estilo.simbolo} ${diferencia.abs()}',
        textAlign: TextAlign.end,
        style: context.tipografia.cuerpoPequeno.copyWith(
          color: estilo.texto,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
