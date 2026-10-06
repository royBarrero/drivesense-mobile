import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../../telemetria/models/event_detector.dart';
import 'live_alert_capsules.dart';

/// "Eventos de este viaje" (HU-14): cuántos hubo de cada tipo, incluidos los
/// de antes de continuar un viaje interrumpido. En 0, en gris.
class TarjetaEventosViaje extends StatelessWidget {
  const TarjetaEventosViaje({super.key, required this.eventos});

  final List<EventoRiesgo> eventos;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Etiqueta('Eventos de este viaje'),
          const SizedBox(height: Espacios.s),
          Row(
            children: [
              for (final (i, tipo) in TipoEvento.values.indexed) ...[
                if (i > 0) const SizedBox(width: Espacios.xs),
                Expanded(
                  child: ContadorEvento(
                    tipo: tipo,
                    cantidad: eventos.where((e) => e.tipo == tipo).length,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class ContadorEvento extends StatelessWidget {
  const ContadorEvento({super.key, required this.tipo, required this.cantidad});

  final TipoEvento tipo;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estilo = EstiloEvento.de(tipo, colores);
    final sinEventos = cantidad == 0;
    final color = sinEventos ? colores.textoSecundario : estilo.texto;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Espacios.s),
      decoration: BoxDecoration(
        color: sinEventos ? colores.superficieAlt : estilo.tinte,
        borderRadius: BorderRadius.circular(Radios.micro),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(estilo.icono, size: Medidas.iconoPequeno, color: color),
              const SizedBox(width: Espacios.xxs),
              Text(
                '$cantidad',
                style: tipografia.numeroMetrica.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            estilo.contador,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tipografia.ayuda.copyWith(color: colores.textoSecundario),
          ),
        ],
      ),
    );
  }
}
