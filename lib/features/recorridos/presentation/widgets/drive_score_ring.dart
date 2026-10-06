import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Anillo del DriveScore sobre fondo oscuro (HU-15, docs/diseno.md 7.1): arco
/// con `gradienteScore` proporcional al puntaje, empezando arriba.
///
/// Sin [puntaje]: con [esperando], solo el carril y una nube (el viaje aún no
/// llegó al backend); si no, "—" (no se pudo obtener).
///
/// [AnilloDriveScore.claro]: versión pequeña sobre una tarjeta blanca (detalle
/// del viaje, HU-16; Inicio, HU-17; resumen, HU-29), solo con el número; sin
/// [puntaje], la nube con [esperando] o "—".
class AnilloDriveScore extends StatelessWidget {
  const AnilloDriveScore({
    super.key,
    this.puntaje,
    this.esperando = false,
    this.tamano = Medidas.anilloResumen,
  }) : claro = false;

  const AnilloDriveScore.claro({
    super.key,
    required this.puntaje,
    this.esperando = false,
    this.tamano = Medidas.anilloDetalle,
  }) : claro = true;

  final int? puntaje;
  final bool esperando;
  final bool claro;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final puntaje = this.puntaje;

    if (claro) {
      return SizedBox.square(
        dimension: tamano,
        child: CustomPaint(
          painter: _AnilloPainter(
            fraccion: (puntaje ?? 0) / 100,
            carril: colores.carril,
            degradado: colores.gradienteScore,
            trazo: Medidas.trazoAnilloPequeno,
          ),
          child: Center(
            child: puntaje == null && esperando
                ? Icon(
                    Icons.cloud_upload_outlined,
                    size: Medidas.iconoNavegacion,
                    color: colores.textoTerciario,
                  )
                : Text(
                    puntaje?.toString() ?? '—',
                    style: tipografia.puntaje.copyWith(
                      color: puntaje == null
                          ? colores.textoTerciario
                          : colores.textoPrincipal,
                    ),
                  ),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: tamano,
      child: CustomPaint(
        painter: _AnilloPainter(
          fraccion: (puntaje ?? 0) / 100,
          carril: colores.encabezadoBorde,
          degradado: colores.gradienteScore,
          trazo: Medidas.trazoAnillo,
        ),
        child: Center(
          child: puntaje == null && esperando
              ? Icon(
                  Icons.cloud_upload_outlined,
                  size: Medidas.iconoEstado,
                  color: colores.encabezadoTextoSecundario,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      puntaje?.toString() ?? '—',
                      style: tipografia.puntajeAnillo.copyWith(
                        color: puntaje == null
                            ? colores.encabezadoTextoSecundario
                            : colores.encabezadoTexto,
                      ),
                    ),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      'DriveScore',
                      style: tipografia.ayuda.copyWith(
                        color: colores.encabezadoTextoSecundario,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  _AnilloPainter({
    required this.fraccion,
    required this.carril,
    required this.degradado,
    required this.trazo,
  });

  final double fraccion;
  final Color carril;
  final LinearGradient degradado;
  final double trazo;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - trazo) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = carril
        ..style = PaintingStyle.stroke
        ..strokeWidth = trazo,
    );
    if (fraccion <= 0) return;

    final barrido = 2 * math.pi * fraccion.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      barrido,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trazo
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: degradado.colors,
          endAngle: barrido,
          // El barrido empieza arriba, igual que el arco
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter oldDelegate) =>
      oldDelegate.fraccion != fraccion ||
      oldDelegate.carril != carril ||
      oldDelegate.degradado != degradado ||
      oldDelegate.trazo != trazo;
}
