import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// Caja del logo con el velocímetro en trazo + "DriveSense". Pensado para fondos oscuros.
class LogoDriveSense extends StatelessWidget {
  const LogoDriveSense({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Medidas.logo,
          height: Medidas.logo,
          decoration: BoxDecoration(
            color: colores.encabezadoSuperficie,
            borderRadius: BorderRadius.circular(Radios.logo),
            border: Border.all(color: colores.encabezadoBorde),
          ),
          padding: const EdgeInsets.all(Espacios.s - 1),
          child: CustomPaint(
            painter: _VelocimetroPainter(colores.encabezadoAcento),
          ),
        ),
        const SizedBox(width: Espacios.s),
        Text(
          'DriveSense',
          style: context.tipografia.marca.copyWith(
            color: colores.encabezadoTexto,
          ),
        ),
      ],
    );
  }
}

/// Arco de 240° con marcas y una aguja, en trazo.
class _VelocimetroPainter extends CustomPainter {
  _VelocimetroPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centro = Offset(size.width / 2, size.height * 0.58);
    final radio = size.width / 2 - 1;

    // El arco empieza abajo a la izquierda (150°) y recorre 240°
    const inicio = 150 * math.pi / 180;
    const barrido = 240 * math.pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      inicio,
      barrido,
      false,
      trazo,
    );

    // Aguja apuntando arriba a la derecha
    const angulo = -50 * math.pi / 180;
    final punta =
        centro + Offset(math.cos(angulo), math.sin(angulo)) * (radio * 0.72);
    canvas.drawLine(centro, punta, trazo);
    canvas.drawCircle(centro, 1.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_VelocimetroPainter oldDelegate) =>
      oldDelegate.color != color;
}
