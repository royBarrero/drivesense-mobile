import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../recorridos/models/trip_score.dart';
import '../../../recorridos/presentation/widgets/live_alert_capsules.dart';

/// Ícono de cada desafío (HU-22); el backend solo manda el código. Los de punto
/// débil usan el del evento de su categoría.
IconData iconoDesafio(String codigo) => switch (codigo) {
  'semana_activa' => Icons.event_repeat_rounded,
  'kilometros_seguros' => Icons.route_rounded,
  'viaje_perfecto' => Icons.verified_outlined,
  'racha_excelente' => Icons.local_fire_department_rounded,
  'promedio_muy_bueno' => Icons.insights_rounded,
  _ => Icons.flag_rounded,
};

/// Caja del ícono del desafío: `tintePrimario` / `primarioOscuro`; el de punto
/// débil, con el tinte y el color de texto del evento de su categoría. Sirve
/// para un [Desafio] y para un `DesafioCompletado` del resumen del viaje.
class CajaDesafio extends StatelessWidget {
  const CajaDesafio({
    super.key,
    required this.codigo,
    this.categoria,
    this.tamano = Medidas.cajaIconoFila,
  });

  final String codigo;

  /// Solo en el punto débil.
  final CategoriaPuntaje? categoria;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final categoria = this.categoria;
    final estilo = categoria == null
        ? null
        : EstiloEvento.de(categoria.tipo, colores);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: estilo?.tinte ?? colores.tintePrimario,
        borderRadius: BorderRadius.circular(Radios.cajaIcono),
      ),
      child: Icon(
        estilo?.icono ?? iconoDesafio(codigo),
        size: tamano >= Medidas.cajaIconoFila
            ? Medidas.icono
            : Medidas.iconoPequeno,
        color: estilo?.texto ?? colores.primarioOscuro,
      ),
    );
  }
}

/// "Completado" con el check, en cápsula `tintePrimario`.
class CapsulaCompletado extends StatelessWidget {
  const CapsulaCompletado({super.key});

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: Medidas.iconoPequeno,
            color: colores.primarioOscuro,
          ),
          const SizedBox(width: Espacios.xxs),
          Text(
            'Completado',
            style: context.tipografia.ayuda.copyWith(
              color: colores.primarioOscuro,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
