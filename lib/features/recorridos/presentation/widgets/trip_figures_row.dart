import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../trip_format.dart';

/// Cifras del viaje en una tarjeta de una fila: distancia, duración y
/// velocidades (resumen y detalle del viaje).
class FilaCifras extends StatelessWidget {
  const FilaCifras({
    super.key,
    required this.distanciaM,
    required this.duracionS,
    required this.velocidadMaximaKmh,
    required this.velocidadPromedioKmh,
  });

  final double distanciaM;
  final int duracionS;
  final double velocidadMaximaKmh;
  final double velocidadPromedioKmh;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.m,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Row(
        children: [
          _Cifra(
            valor: FormatoViaje.kilometros(distanciaM),
            unidad: 'km',
            etiqueta: 'Distancia',
          ),
          _Cifra(valor: FormatoViaje.duracion(duracionS), etiqueta: 'Duración'),
          _Cifra(
            valor: FormatoViaje.velocidad(velocidadMaximaKmh),
            unidad: 'km/h',
            etiqueta: 'Vel. máx.',
          ),
          _Cifra(
            valor: FormatoViaje.velocidad(velocidadPromedioKmh),
            unidad: 'km/h',
            etiqueta: 'Vel. prom.',
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta, this.unidad});

  final String valor;
  final String etiqueta;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Expanded(
      child: Column(
        children: [
          // Un viaje de más de una hora ("1:05:32") se achica en vez de cortarse
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: valor,
                    style: tipografia.numeroLista.copyWith(
                      color: colores.textoPrincipal,
                    ),
                  ),
                  if (unidad != null)
                    TextSpan(
                      text: ' $unidad',
                      style: tipografia.ayuda.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            etiqueta,
            style: tipografia.ayuda.copyWith(color: colores.textoSecundario),
          ),
        ],
      ),
    );
  }
}
