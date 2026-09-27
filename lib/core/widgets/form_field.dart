import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design.dart';

/// Campo de formulario con la etiqueta encima (docs/diseno.md, 4.1).
///
/// [conError] pinta el borde en rojo; [mensajeError] (opcional) se muestra debajo
/// y reemplaza a [ayuda]. [debajo] se muestra siempre al final (p. ej. requisitos).
class CampoFormulario extends StatelessWidget {
  const CampoFormulario({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.conError = false,
    this.mensajeError,
    this.ayuda,
    this.debajo,
    this.habilitado = true,
    this.ocultarTexto = false,
    this.teclado,
    this.accionTeclado,
    this.alEnviar,
    this.alCambiar,
    this.alPerderFoco,
    this.autocompletado,
    this.formateadores,
    this.mayusculas = TextCapitalization.none,
    this.margenDesplazamiento = const EdgeInsets.all(20),
    this.sufijo,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final bool conError;
  final String? mensajeError;
  final String? ayuda;
  final Widget? debajo;
  final bool habilitado;
  final bool ocultarTexto;
  final TextInputType? teclado;
  final TextInputAction? accionTeclado;
  final ValueChanged<String>? alEnviar;
  final ValueChanged<String>? alCambiar;

  /// Se llama cuando el campo pierde el foco (para validar al salir del campo).
  final VoidCallback? alPerderFoco;
  final Iterable<String>? autocompletado;
  final List<TextInputFormatter>? formateadores;
  final TextCapitalization mayusculas;

  /// Espacio que se deja visible alrededor del campo al desplazarse con el teclado.
  final EdgeInsets margenDesplazamiento;
  final Widget? sufijo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final hayError = conError || mensajeError != null;
    final tema = Theme.of(context).inputDecorationTheme;
    final textoInferior = mensajeError ?? ayuda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: tipografia.etiquetaCampo.copyWith(
            color: colores.textoPrincipal,
          ),
        ),
        const SizedBox(height: Espacios.xs),
        Focus(
          // Solo escucha el foco del TextField; no es un punto de foco propio
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (tieneFoco) {
            if (!tieneFoco) alPerderFoco?.call();
          },
          child: TextField(
            controller: controlador,
            enabled: habilitado,
            obscureText: ocultarTexto,
            keyboardType: teclado,
            textInputAction: accionTeclado,
            textCapitalization: mayusculas,
            inputFormatters: formateadores,
            scrollPadding: margenDesplazamiento,
            onSubmitted: alEnviar,
            onChanged: alCambiar,
            autofillHints: autocompletado,
            autocorrect: false,
            enableSuggestions: !ocultarTexto,
            style: tipografia.cuerpo.copyWith(color: colores.textoPrincipal),
            decoration: InputDecoration(
              suffixIcon: sufijo,
              // El mensaje va fuera del campo; aquí solo se cambia el borde
              enabledBorder: hayError ? tema.errorBorder : null,
              focusedBorder: hayError ? tema.focusedErrorBorder : null,
              disabledBorder: hayError ? tema.errorBorder : null,
            ),
          ),
        ),
        if (textoInferior != null) ...[
          const SizedBox(height: Espacios.xxs + 2),
          Text(
            textoInferior,
            style: tipografia.ayuda.copyWith(
              color: mensajeError != null
                  ? colores.textoPeligro
                  : colores.textoSecundario,
            ),
          ),
        ],
        if (debajo != null) ...[const SizedBox(height: Espacios.xs), debajo!],
      ],
    );
  }
}
