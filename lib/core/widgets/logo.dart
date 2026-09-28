import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// Caja del logo con el velocímetro en trazo + "DriveSense".
///
/// Por defecto, para fondos oscuros (login, registro, arranque). [compacto]:
/// caja de 36 y texto oscuro, para la cabecera clara de Inicio (docs/diseno.md, 7.1).
class LogoDriveSense extends StatelessWidget {
  const LogoDriveSense({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compacto ? Medidas.cajaIcono : Medidas.logo,
          height: compacto ? Medidas.cajaIcono : Medidas.logo,
          decoration: BoxDecoration(
            color: compacto
                ? colores.encabezadoFondo
                : colores.encabezadoSuperficie,
            borderRadius: BorderRadius.circular(
              compacto ? Radios.cajaIcono : Radios.logo,
            ),
            border: compacto
                ? null
                : Border.all(color: colores.encabezadoBorde),
          ),
          padding: EdgeInsets.all(compacto ? Espacios.xs : Espacios.s - 1),
          child: CustomPaint(
            painter: _VelocimetroPainter(colores.encabezadoAcento),
          ),
        ),
        SizedBox(width: compacto ? Espacios.xs + 2 : Espacios.s),
        Text(
          'DriveSense',
          style: compacto
              ? tipografia.subtitulo.copyWith(color: colores.textoPrincipal)
              : tipografia.marca.copyWith(color: colores.encabezadoTexto),
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
