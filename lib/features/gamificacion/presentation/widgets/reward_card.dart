import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/label.dart';
import '../../models/progress.dart';
import 'achievement_widgets.dart';
import 'challenge_widgets.dart';

/// Aviso del resumen del viaje (HU-21, HU-23): puntos ganados (viaje, desafíos
/// y bono), subida de nivel, desafíos semanales completados y logros nuevos.
/// Solo se muestra si hay novedades ([RecompensaViaje.hayNovedades]); tocarla
/// abre los logros.
class TarjetaRecompensa extends StatelessWidget {
  const TarjetaRecompensa({
    super.key,
    required this.recompensa,
    this.alPresionar,
  });

  final RecompensaViaje recompensa;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final nivel = recompensa.nivel;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Material(
        color: colores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.tarjeta),
          side: BorderSide(color: colores.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(Espacios.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Etiqueta('Recompensa')),
                    CapsulaPuntos(puntos: recompensa.puntosTotal),
                    if (alPresionar != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: Medidas.iconoNavegacion,
                        color: colores.textoSecundario,
                      ),
                  ],
                ),
                if (recompensa.subioDeNivel) ...[
                  const SizedBox(height: Espacios.s),
                  Row(
                    children: [
                      Container(
                        width: Medidas.cajaIconoFila,
                        height: Medidas.cajaIconoFila,
                        decoration: BoxDecoration(
                          color: colores.tintePrimario,
                          borderRadius: BorderRadius.circular(Radios.cajaIcono),
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          size: Medidas.icono,
                          color: colores.primarioOscuro,
                        ),
                      ),
                      const SizedBox(width: Espacios.m),
                      Expanded(
                        child: Text(
                          '¡Subiste a nivel ${nivel.numero}: ${nivel.nombre}!',
                          style: tipografia.subtitulo.copyWith(
                            color: colores.textoPrincipal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                for (final desafio in recompensa.desafiosCompletados) ...[
                  const SizedBox(height: Espacios.s),
                  _FilaRecompensa(
                    icono: CajaDesafio(
                      codigo: desafio.codigo,
                      categoria: desafio.categoria,
                    ),
                    etiqueta: 'Desafío completado',
                    texto: desafio.nombre,
                    puntos: desafio.puntos,
                  ),
                ],
                if (recompensa.bono case final bono?) ...[
                  const SizedBox(height: Espacios.s),
                  _FilaRecompensa(
                    icono: Container(
                      width: Medidas.cajaIconoFila,
                      height: Medidas.cajaIconoFila,
                      decoration: BoxDecoration(
                        color: colores.tintePrimario,
                        borderRadius: BorderRadius.circular(Radios.cajaIcono),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: Medidas.icono,
                        color: colores.primarioOscuro,
                      ),
                    ),
                    etiqueta: 'Bono semanal',
                    texto: '¡Completaste los 3 desafíos!',
                    puntos: bono,
                  ),
                ],
                for (final logro in recompensa.logrosNuevos) ...[
                  const SizedBox(height: Espacios.s),
                  Row(
                    children: [
                      CajaLogro(codigo: logro.codigo),
                      const SizedBox(width: Espacios.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logro desbloqueado',
                              style: tipografia.ayuda.copyWith(
                                color: colores.primarioOscuro,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              logro.nombre,
                              style: tipografia.cuerpo.copyWith(
                                color: colores.textoPrincipal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de la tarjeta (desafío o bono): caja de 44, la etiqueta en verde, el
/// texto y, a la derecha, los puntos.
class _FilaRecompensa extends StatelessWidget {
  const _FilaRecompensa({
    required this.icono,
    required this.etiqueta,
    required this.texto,
    required this.puntos,
  });

  final Widget icono;
  final String etiqueta;
  final String texto;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      children: [
        icono,
        const SizedBox(width: Espacios.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: tipografia.ayuda.copyWith(
                  color: colores.primarioOscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                texto,
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoPrincipal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espacios.s),
        CapsulaPuntos(puntos: puntos),
      ],
    );
  }
}
