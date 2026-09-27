import 'package:flutter/material.dart';

import '../design/design.dart';

/// Aviso de error con ícono de alerta (docs/diseno.md, 4.1).
class AvisoError extends StatelessWidget {
  const AvisoError({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: colores.tintePeligro,
        borderRadius: BorderRadius.circular(Radios.campo),
        border: Border.all(color: colores.bordePeligroSuave),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: Medidas.icono,
            color: colores.textoPeligro,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              mensaje,
              style: context.tipografia.cuerpoPequeno.copyWith(
                color: colores.textoPeligro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
