import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Pestaña Viajes. Por ahora solo el estado vacío; el historial es la HU-06.
class ViajesPantalla extends StatelessWidget {
  const ViajesPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Espacios.l,
          Espacios.l,
          Espacios.l,
          MediaQuery.paddingOf(context).bottom + Espacios.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Viajes',
              style: tipografia.titulo.copyWith(color: colores.textoPrincipal),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: Medidas.cajaIcono,
                      height: Medidas.cajaIcono,
                      decoration: BoxDecoration(
                        color: colores.tintePrimario,
                        borderRadius: BorderRadius.circular(Radios.cajaIcono),
                      ),
                      child: Icon(
                        Icons.route_outlined,
                        size: Medidas.icono,
                        color: colores.primarioOscuro,
                      ),
                    ),
                    const SizedBox(height: Espacios.m),
                    Text(
                      'Aún no tienes viajes',
                      style: tipografia.subtitulo.copyWith(
                        color: colores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      'Cuando finalices tu primer recorrido, aparecerá aquí.',
                      textAlign: TextAlign.center,
                      style: tipografia.cuerpo.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
