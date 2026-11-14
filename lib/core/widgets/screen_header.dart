import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../design/design.dart';

/// Piezas comunes de las pantallas sobre la barra: Mi DriveScore (HU-17), el
/// comparativo (HU-20) y los logros (HU-21).

/// Tarjeta grande: `superficie`, radio 24, borde y `sombraTarjeta`.
BoxDecoration decoracionTarjeta(ColoresDriveSense colores) => BoxDecoration(
  color: colores.superficie,
  borderRadius: BorderRadius.circular(Radios.tarjeta),
  border: Border.all(color: colores.borde),
  boxShadow: colores.sombraTarjeta,
);

/// Volver en caja de 44 blanca; sin pantalla anterior, a [alternativa].
class BotonVolverCaja extends StatelessWidget {
  const BotonVolverCaja({super.key, this.alternativa = Rutas.inicio});

  final String alternativa;

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
        onTap: () => context.canPop() ? context.pop() : context.go(alternativa),
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
class CabeceraPantalla extends StatelessWidget {
  const CabeceraPantalla({
    super.key,
    required this.titulo,
    this.alternativa = Rutas.inicio,
  });

  final String titulo;

  /// Adónde vuelve si no hay pantalla anterior.
  final String alternativa;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BotonVolverCaja(alternativa: alternativa),
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
