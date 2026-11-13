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

/// Cambio de una cifra del comparativo (HU-20): "▲ 2", "▼ 1,4" o "=". El
/// símbolo sigue el signo de [diferencia] y el color, [mejora]: verde si
/// mejoró, rojo si empeoró y gris si es igual o nulo (viajes y km, que no son
/// mejores ni peores por sí mismos). [texto] es la diferencia ya formateada,
/// sin signo.
class CambioCifra extends StatelessWidget {
  const CambioCifra({
    super.key,
    required this.diferencia,
    required this.texto,
    this.mejora,
  });

  final double diferencia;
  final String texto;
  final bool? mejora;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final simbolo = switch (diferencia) {
      > 0 => '▲',
      < 0 => '▼',
      _ => '=',
    };
    final color = diferencia == 0
        ? colores.textoSecundario
        : switch (mejora) {
            true => colores.primarioOscuro,
            false => colores.textoPeligro,
            null => colores.textoSecundario,
          };
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: Medidas.cajaIcono),
      child: Text(
        diferencia == 0 ? simbolo : '$simbolo $texto',
        textAlign: TextAlign.end,
        maxLines: 1,
        style: context.tipografia.cuerpoPequeno.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
