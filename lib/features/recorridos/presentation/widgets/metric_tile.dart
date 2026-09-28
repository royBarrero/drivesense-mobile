import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';

/// Micro-tarjeta blanca del viaje en vivo (docs/diseno.md, 7.1): caja de ícono
/// tintada de 36, label y valor en `numeroGrande`.
class TarjetaMetrica extends StatelessWidget {
  const TarjetaMetrica({
    super.key,
    required this.icono,
    required this.tinte,
    required this.colorIcono,
    required this.etiqueta,
    required this.valor,
    this.unidad,
  });

  final IconData icono;
  final Color tinte;
  final Color colorIcono;
  final String etiqueta;
  final String valor;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;

    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.micro),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Medidas.cajaIcono,
                height: Medidas.cajaIcono,
                decoration: BoxDecoration(
                  color: tinte,
                  borderRadius: BorderRadius.circular(Radios.cajaIcono),
                ),
                child: Icon(icono, size: Medidas.icono, color: colorIcono),
              ),
              const SizedBox(width: Espacios.s),
              Flexible(child: Etiqueta(etiqueta)),
            ],
          ),
          const SizedBox(height: Espacios.s),
          _Valor(
            valor: valor,
            unidad: unidad,
            estilo: context.tipografia.numeroGrande,
          ),
        ],
      ),
    );
  }
}

/// Micro-tarjeta tintada del resumen (docs/diseno.md, 6): ícono y label arriba,
/// valor en `puntaje` (Space Grotesk 28).
class MetricaTintada extends StatelessWidget {
  const MetricaTintada({
    super.key,
    required this.icono,
    required this.tinte,
    required this.colorIcono,
    required this.etiqueta,
    required this.valor,
    this.unidad,
  });

  final IconData icono;
  final Color tinte;
  final Color colorIcono;
  final String etiqueta;
  final String valor;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: tinte,
        borderRadius: BorderRadius.circular(Radios.micro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: Medidas.iconoPequeno, color: colorIcono),
              const SizedBox(width: Espacios.xxs + 2),
              Flexible(child: Etiqueta(etiqueta)),
            ],
          ),
          const SizedBox(height: Espacios.xs),
          _Valor(
            valor: valor,
            unidad: unidad,
            estilo: context.tipografia.puntaje,
          ),
        ],
      ),
    );
  }
}

class _Valor extends StatelessWidget {
  const _Valor({
    required this.valor,
    required this.unidad,
    required this.estilo,
  });

  final String valor;
  final String? unidad;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return FittedBox(
      // Un valor largo (p. ej. 1:05:12) se reduce en vez de desbordar
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: valor),
            if (unidad != null)
              TextSpan(
                text: ' $unidad',
                style: context.tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
          ],
        ),
        style: estilo.copyWith(color: colores.textoPrincipal),
      ),
    );
  }
}
