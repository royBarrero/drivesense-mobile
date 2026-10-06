import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Botón blanco sobre el mapa (volver, ver la ruta entera, expandir).
class BotonMapa extends StatelessWidget {
  const BotonMapa({
    super.key,
    required this.icono,
    required this.descripcion,
    required this.alPresionar,
    this.circular = false,
  });

  final IconData icono;
  final String descripcion;
  final VoidCallback alPresionar;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final forma = circular
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radios.campo),
          );
    return DecoratedBox(
      decoration: ShapeDecoration(shape: forma, shadows: colores.sombraTarjeta),
      child: Material(
        color: colores.superficie,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: alPresionar,
          child: Tooltip(
            message: descripcion,
            child: SizedBox.square(
              dimension: Medidas.botonVolver,
              child: Icon(
                icono,
                size: Medidas.iconoNavegacion,
                color: colores.textoPrincipal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
