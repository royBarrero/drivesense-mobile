import 'package:flutter/material.dart';

import '../design/design.dart';

/// Label de métrica o de sección EN MAYÚSCULAS (docs/diseno.md, 2).
///
/// El texto se escribe normal (`Etiqueta('Velocidad')`); las mayúsculas las pone el widget.
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.grande = false, this.color});

  final String texto;

  /// `etiquetaGrande` (labels de sección) en vez de `etiqueta` (labels de métrica).
  final bool grande;

  /// Por defecto `textoSecundario`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tipografia = context.tipografia;
    return Text(
      texto.toUpperCase(),
      style: (grande ? tipografia.etiquetaGrande : tipografia.etiqueta)
          .copyWith(color: color ?? context.colores.textoSecundario),
    );
  }
}
