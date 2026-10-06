import 'package:flutter/material.dart';

import '../design/design.dart';

/// Chips en cápsula para elegir un periodo (docs/diseno.md, 4): el historial
/// ("Esta semana", "Este mes", "Todos") y Mi DriveScore ("7 días"…).
class ChipsPeriodo<T> extends StatelessWidget {
  const ChipsPeriodo({
    super.key,
    required this.opciones,
    required this.texto,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  final List<T> opciones;
  final String Function(T opcion) texto;
  final T seleccionado;
  final ValueChanged<T> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

    return Wrap(
      spacing: Espacios.xs,
      runSpacing: Espacios.xs,
      children: [
        for (final opcion in opciones)
          Semantics(
            button: true,
            selected: opcion == seleccionado,
            child: GestureDetector(
              onTap: () => alSeleccionar(opcion),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: Espacios.m,
                  vertical: Espacios.xs,
                ),
                decoration: BoxDecoration(
                  color: opcion == seleccionado
                      ? colores.textoPrincipal
                      : colores.superficie,
                  borderRadius: BorderRadius.circular(Radios.pildora),
                  border: Border.all(
                    color: opcion == seleccionado
                        ? colores.textoPrincipal
                        : colores.borde,
                  ),
                ),
                child: Text(
                  texto(opcion),
                  style: tipografia.cuerpoPequeno.copyWith(
                    fontWeight: FontWeight.w600,
                    color: opcion == seleccionado
                        ? colores.sobrePrimario
                        : colores.textoSecundario,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
