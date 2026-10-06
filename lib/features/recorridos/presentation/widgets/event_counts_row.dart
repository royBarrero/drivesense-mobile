import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../telemetria/models/event_detector.dart';
import 'live_alert_capsules.dart';

/// Cuántos eventos hubo de cada tipo (HU-29): caja tintada con el ícono, el
/// número y el nombre ("Frenadas", "Aceleraciones", "Giros", "Excesos"). En 0,
/// en gris.
class FilaConteoEventos extends StatelessWidget {
  const FilaConteoEventos({super.key, required this.conteo});

  /// Conteo por tipo; un tipo que falta cuenta como 0.
  final Map<TipoEvento, int> conteo;

  /// Conteo de una lista de eventos, con los cuatro tipos.
  static Map<TipoEvento, int> contar(Iterable<EventoRiesgo> eventos) => {
    for (final tipo in TipoEvento.values)
      tipo: eventos.where((e) => e.tipo == tipo).length,
  };

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      children: [
        for (final tipo in TipoEvento.values)
          Expanded(
            child: Builder(
              builder: (context) {
                final estilo = EstiloEvento.de(tipo, colores);
                final cantidad = conteo[tipo] ?? 0;
                final sinEventos = cantidad == 0;
                return Column(
                  children: [
                    Container(
                      width: Medidas.cajaIconoContador,
                      height: Medidas.cajaIconoContador,
                      decoration: BoxDecoration(
                        color: sinEventos
                            ? colores.superficieAlt
                            : estilo.tinte,
                        borderRadius: BorderRadius.circular(Radios.cajaIcono),
                      ),
                      child: Icon(
                        estilo.icono,
                        size: Medidas.icono,
                        color: sinEventos
                            ? colores.textoTerciario
                            : estilo.texto,
                      ),
                    ),
                    const SizedBox(height: Espacios.xs),
                    Text(
                      '$cantidad',
                      style: tipografia.puntaje.copyWith(
                        color: sinEventos
                            ? colores.textoTerciario
                            : colores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      estilo.plural,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
