import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/logo.dart';
import '../../../../core/widgets/illustration_painters.dart';

enum IlustracionEncabezado { completa, reducida }

/// Bloque oscuro superior de las pantallas de login y registro
/// (docs/diseno.md, 4.2). Se usa dentro de `PantallaAuth`, que pone la barra de
/// estado encima: por eso aquí no se reserva su espacio.
///
/// Con [alto] nulo se ajusta al contenido (mínimo [altoMinimo]) y deja abajo el
/// espacio que ocupa la tarjeta superpuesta.
class EncabezadoAuth extends StatelessWidget {
  const EncabezadoAuth({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.alto,
    this.altoMinimo = 0,
    this.alVolver,
    this.ilustracion = IlustracionEncabezado.completa,
  });

  final String titulo;
  final String subtitulo;
  final double? alto;
  final double altoMinimo;

  /// Si no es nulo, muestra la flecha de volver junto al logo.
  final VoidCallback? alVolver;
  final IlustracionEncabezado ilustracion;

  static const _anchoMaximoTexto = 260.0;
  static const _ladoCirculos = 88.0;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final altoAjustable = alto == null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radios.encabezado),
      ),
      child: Container(
        width: double.infinity,
        constraints: altoAjustable
            ? BoxConstraints(minHeight: altoMinimo)
            : BoxConstraints.tightFor(height: alto),
        color: colores.encabezadoFondo,
        child: Stack(
          children: [
            if (ilustracion == IlustracionEncabezado.completa)
              Positioned.fill(
                child: CustomPaint(
                  painter: IlustracionRutaPainter(
                    colorLineas: colores.encabezadoBorde,
                    colorAcento: colores.encabezadoAcento,
                  ),
                ),
              )
            else
              Positioned(
                top: Espacios.s,
                right: Espacios.s,
                width: _ladoCirculos,
                height: _ladoCirculos,
                child: CustomPaint(
                  painter: CirculosReducidosPainter(
                    colorLineas: colores.encabezadoBorde,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                // La flecha trae su propio margen interno (área táctil de 44)
                alVolver == null ? Espacios.xl : Espacios.s,
                Espacios.l,
                Espacios.xl,
                // Espacio para la tarjeta superpuesta + separación
                altoAjustable ? Medidas.superposicionTarjeta + Espacios.xl : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (alVolver != null) ...[
                        IconButton(
                          onPressed: alVolver,
                          tooltip: 'Volver',
                          constraints: const BoxConstraints.tightFor(
                            width: Medidas.botonVolver,
                            height: Medidas.botonVolver,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back,
                            size: Medidas.iconoNavegacion,
                            color: colores.encabezadoTexto,
                          ),
                        ),
                        const SizedBox(width: Espacios.xxs),
                      ],
                      const LogoDriveSense(),
                    ],
                  ),
                  SizedBox(
                    height: alVolver == null ? Espacios.xxl : Espacios.xl,
                  ),
                  Padding(
                    // Alinea los textos con el logo cuando hay flecha
                    padding: EdgeInsets.only(
                      left: alVolver == null ? 0 : Espacios.s,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _anchoMaximoTexto,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: tipografia.tituloHero.copyWith(
                              color: colores.encabezadoTexto,
                            ),
                          ),
                          const SizedBox(height: Espacios.s),
                          Text(
                            subtitulo,
                            style: tipografia.cuerpo.copyWith(
                              color: colores.encabezadoTextoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
