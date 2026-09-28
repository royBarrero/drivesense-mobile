import 'dart:ui';

import 'package:flutter/material.dart';

/// Ilustración decorativa de los bloques oscuros (login, recorrido en vivo):
/// círculos concéntricos con ejes (el del medio punteado), una ruta curva
/// punteada y un punto con resplandor.
///
/// Se dibuja sobre todo el bloque. Por defecto (login) los círculos quedan abajo
/// a la derecha; [centro] los coloca en otro punto y [escala] cambia su tamaño.
class IlustracionRutaPainter extends CustomPainter {
  IlustracionRutaPainter({
    required this.colorLineas,
    required this.colorAcento,
    this.centro,
    this.escala = 1,
    this.conPunto = true,
    this.huecoCentral = 0,
  });

  final Color colorLineas;
  final Color colorAcento;

  /// Centro de los círculos según el tamaño del bloque.
  final Offset Function(Size tamano)? centro;
  final double escala;

  /// Punto con resplandor en el centro; se omite si algo va encima (la velocidad).
  final bool conPunto;

  /// Radio alrededor del centro donde no se dibuja la ruta (deja legible lo que
  /// va encima, como la velocidad).
  final double huecoCentral;

  @override
  void paint(Canvas canvas, Size size) {
    final centro =
        this.centro?.call(size) ?? Offset(size.width - 58, size.height - 128);
    final radios = [26.0 * escala, 50.0 * escala, 74.0 * escala];

    final lineas = Paint()
      ..color = colorLineas
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(centro, radios[0], lineas);
    dibujarPunteado(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centro, radius: radios[1])),
      lineas,
      guion: 4,
      espacio: 5,
    );
    canvas.drawCircle(centro, radios[2], lineas);

    // Ejes cruzados
    final largoEje = 88.0 * escala;
    canvas.drawLine(
      centro.translate(-largoEje, 0),
      centro.translate(largoEje, 0),
      lineas,
    );
    canvas.drawLine(
      centro.translate(0, -largoEje),
      centro.translate(0, largoEje),
      lineas,
    );

    // Ruta curva que cruza el bloque y pasa por el centro de los círculos
    final ruta = Path()
      ..moveTo(-12, size.height - 24)
      ..cubicTo(
        size.width * 0.30,
        size.height - 20,
        size.width * 0.42,
        centro.dy + 70,
        centro.dx,
        centro.dy,
      )
      ..cubicTo(
        centro.dx + 40,
        centro.dy - 50,
        size.width - 20,
        centro.dy - 110,
        size.width + 12,
        centro.dy - 150,
      );
    canvas.save();
    if (huecoCentral > 0) {
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()
            ..addOval(Rect.fromCircle(center: centro, radius: huecoCentral)),
        ),
      );
    }
    dibujarPunteado(
      canvas,
      ruta,
      Paint()
        ..color = colorAcento
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
      guion: 6,
      espacio: 7,
    );
    canvas.restore();

    if (!conPunto) return;

    // Punto con resplandor
    canvas.drawCircle(
      centro,
      11,
      Paint()
        ..color = colorAcento.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(centro, 5, Paint()..color = colorAcento);
  }

  @override
  bool shouldRepaint(IlustracionRutaPainter oldDelegate) =>
      oldDelegate.colorLineas != colorLineas ||
      oldDelegate.colorAcento != colorAcento ||
      oldDelegate.escala != escala ||
      oldDelegate.conPunto != conPunto ||
      oldDelegate.huecoCentral != huecoCentral;
}

/// Solo los 3 círculos (el del medio punteado) con ejes, centrados en el área
/// disponible: encabezado del registro y, con [escala], la tarjeta oscura de Inicio.
class CirculosReducidosPainter extends CustomPainter {
  CirculosReducidosPainter({required this.colorLineas, this.escala = 1});

  final Color colorLineas;
  final double escala;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final lineas = Paint()
      ..color = colorLineas
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(centro, 14 * escala, lineas);
    dibujarPunteado(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centro, radius: 26 * escala)),
      lineas,
      guion: 3,
      espacio: 4,
    );
    canvas.drawCircle(centro, 38 * escala, lineas);

    final largoEje = 44.0 * escala;
    canvas.drawLine(
      centro.translate(-largoEje, 0),
      centro.translate(largoEje, 0),
      lineas,
    );
    canvas.drawLine(
      centro.translate(0, -largoEje),
      centro.translate(0, largoEje),
      lineas,
    );
  }

  @override
  bool shouldRepaint(CirculosReducidosPainter oldDelegate) =>
      oldDelegate.colorLineas != colorLineas || oldDelegate.escala != escala;
}

/// Dibuja [camino] como una línea punteada.
void dibujarPunteado(
  Canvas canvas,
  Path camino,
  Paint pintura, {
  required double guion,
  required double espacio,
}) {
  for (final PathMetric metrica in camino.computeMetrics()) {
    var distancia = 0.0;
    while (distancia < metrica.length) {
      canvas.drawPath(
        metrica.extractPath(distancia, distancia + guion),
        pintura,
      );
      distancia += guion + espacio;
    }
  }
}
