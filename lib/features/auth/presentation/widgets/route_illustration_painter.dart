import 'dart:ui';

import 'package:flutter/material.dart';

/// Ilustración decorativa del encabezado del login: círculos concéntricos con ejes
/// (el del medio punteado), una ruta curva punteada y un punto con resplandor.
///
/// Se dibuja sobre todo el encabezado; el conjunto de círculos queda abajo a la derecha.
class IlustracionRutaPainter extends CustomPainter {
  IlustracionRutaPainter({
    required this.colorLineas,
    required this.colorAcento,
  });

  final Color colorLineas;
  final Color colorAcento;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width - 58, size.height - 128);
    const radios = [26.0, 50.0, 74.0];

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
    const largoEje = 88.0;
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
      oldDelegate.colorAcento != colorAcento;
}

/// Versión reducida para el encabezado del registro: solo los 3 círculos
/// (el del medio punteado) con ejes, centrados en el área disponible.
class CirculosReducidosPainter extends CustomPainter {
  CirculosReducidosPainter({required this.colorLineas});

  final Color colorLineas;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final lineas = Paint()
      ..color = colorLineas
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(centro, 14, lineas);
    dibujarPunteado(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centro, radius: 26)),
      lineas,
      guion: 3,
      espacio: 4,
    );
    canvas.drawCircle(centro, 38, lineas);

    const largoEje = 44.0;
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
      oldDelegate.colorLineas != colorLineas;
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
