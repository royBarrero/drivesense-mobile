import 'package:flutter/material.dart';

import '../design/design.dart';

/// Botón píldora de acento para fondos oscuros (docs/diseno.md, 4):
/// fondo `encabezadoAcento`, texto `sobreAcentoOscuro` y sombra verde suave.
///
/// Con [alPresionar] nulo queda deshabilitado; con [cargando] muestra un indicador.
class BotonAcento extends StatelessWidget {
  const BotonAcento({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final habilitado = alPresionar != null && !cargando;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: habilitado ? colores.sombraBotonAcento : null,
      ),
      child: FilledButton(
        onPressed: habilitado ? alPresionar : null,
        style: FilledButton.styleFrom(
          backgroundColor: colores.encabezadoAcento,
          foregroundColor: colores.sobreAcentoOscuro,
          // Mientras carga se mantiene el color activo
          disabledBackgroundColor: cargando
              ? colores.encabezadoAcento
              : colores.encabezadoBorde,
          disabledForegroundColor: cargando
              ? colores.sobreAcentoOscuro
              : colores.encabezadoTextoSecundario,
          overlayColor: colores.sobreAcentoOscuro,
        ),
        child: cargando
            ? SizedBox.square(
                dimension: Medidas.icono,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colores.sobreAcentoOscuro,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: Medidas.icono),
                    const SizedBox(width: Espacios.xs),
                  ],
                  Flexible(child: Text(texto)),
                ],
              ),
      ),
    );
  }
}
