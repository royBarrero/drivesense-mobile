import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/design/design.dart';

/// Piezas comunes de Mi DriveScore (HU-17) y el comparativo (HU-20).

/// Tarjeta grande: `superficie`, radio 24, borde y `sombraTarjeta`.
BoxDecoration decoracionTarjeta(ColoresDriveSense colores) => BoxDecoration(
  color: colores.superficie,
  borderRadius: BorderRadius.circular(Radios.tarjeta),
  border: Border.all(color: colores.borde),
  boxShadow: colores.sombraTarjeta,
);

/// Volver en caja de 44 blanca; sin pantalla anterior, a Inicio.
class BotonVolverCaja extends StatelessWidget {
  const BotonVolverCaja({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.campo),
        side: BorderSide(color: colores.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.campo),
        onTap: () =>
            context.canPop() ? context.pop() : context.go(Rutas.inicio),
        child: SizedBox.square(
          dimension: Medidas.botonVolver,
          child: Icon(
            Icons.chevron_left_rounded,
            size: Medidas.iconoNavegacion,
            color: colores.textoPrincipal,
          ),
        ),
      ),
    );
  }
}

/// Fila superior: volver y el título de la pantalla.
class CabeceraPuntaje extends StatelessWidget {
  const CabeceraPuntaje({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BotonVolverCaja(),
        const SizedBox(width: Espacios.m),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tipografia.titulo.copyWith(
              color: context.colores.textoPrincipal,
            ),
          ),
        ),
      ],
    );
  }
}
