import 'package:flutter/material.dart';

import '../design/design.dart';

/// Botón píldora principal (docs/diseno.md, sección 4).
///
/// Con [alPresionar] nulo queda deshabilitado; con [cargando] muestra un indicador.
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final habilitado = alPresionar != null && !cargando;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: habilitado ? colores.sombraBotonPrimario : null,
      ),
      child: FilledButton(
        onPressed: habilitado ? alPresionar : null,
        // Mientras carga se mantiene el color activo, no el de deshabilitado
        style: cargando
            ? FilledButton.styleFrom(
                disabledBackgroundColor: colores.botonPrimario,
                disabledForegroundColor: colores.sobrePrimario,
              )
            : null,
        child: cargando
            ? SizedBox.square(
                dimension: Medidas.icono,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colores.sobrePrimario,
                ),
              )
            : Text(texto),
      ),
    );
  }
}
