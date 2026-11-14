import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Ícono de cada logro (HU-21); el backend solo manda el código.
IconData iconoLogro(String codigo) => switch (codigo) {
  'primer_viaje' => Icons.flag_rounded,
  'viaje_limpio' => Icons.verified_outlined,
  'puntaje_excelente' => Icons.star_rounded,
  'buena_racha' => Icons.local_fire_department_rounded,
  'racha_imparable' => Icons.whatshot_rounded,
  'constante' => Icons.repeat_rounded,
  'veterano' => Icons.military_tech_rounded,
  'cien_kilometros' => Icons.route_rounded,
  'gran_ruta' => Icons.map_rounded,
  _ => Icons.emoji_events_rounded,
};

/// Caja de 44 con el ícono del logro: `tintePrimario` si está desbloqueado,
/// `superficieAlt` con el ícono apagado si no.
class CajaLogro extends StatelessWidget {
  const CajaLogro({super.key, required this.codigo, this.desbloqueado = true});

  final String codigo;
  final bool desbloqueado;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      width: Medidas.cajaIconoFila,
      height: Medidas.cajaIconoFila,
      decoration: BoxDecoration(
        color: desbloqueado ? colores.tintePrimario : colores.superficieAlt,
        borderRadius: BorderRadius.circular(Radios.cajaIcono),
      ),
      child: Icon(
        iconoLogro(codigo),
        size: Medidas.icono,
        color: desbloqueado ? colores.primarioOscuro : colores.textoTerciario,
      ),
    );
  }
}

/// Barra de progreso en cápsula (`altoBarra`, `carril`), como las del desglose.
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({super.key, required this.valor, this.color});

  /// De 0 a 1.
  final double valor;

  /// Por defecto, `primario`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radios.pildora),
      child: LinearProgressIndicator(
        value: valor.clamp(0, 1),
        minHeight: Medidas.altoBarra,
        backgroundColor: colores.carril,
        color: color ?? colores.primario,
      ),
    );
  }
}

/// "+31 pts" en cápsula `tintePrimario` (recompensa del viaje y de los desafíos).
class CapsulaPuntos extends StatelessWidget {
  const CapsulaPuntos({super.key, required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.xxs,
      ),
      decoration: BoxDecoration(
        color: colores.tintePrimario,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Text(
        '+$puntos pts',
        style: context.tipografia.ayuda.copyWith(
          color: colores.primarioOscuro,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
