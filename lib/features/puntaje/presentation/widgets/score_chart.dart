import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../recorridos/presentation/trip_format.dart';
import '../../models/score_history.dart';

/// Gráfico del DriveScore de "Mi DriveScore" (HU-17, docs/diseno.md 7.1): línea
/// con `gradienteScore` y relleno, puntos y líneas guía en 90, 75 y 60. Cada
/// punto va según su fecha entre [desde] y [hasta]; debajo, las fechas del
/// inicio, la mitad y "Hoy". Con un solo punto, solo el punto.
class GraficoDriveScore extends StatelessWidget {
  const GraficoDriveScore({
    super.key,
    required this.puntos,
    required this.desde,
    required this.hasta,
  });

  final List<PuntoHistorico> puntos;
  final DateTime desde;
  final DateTime hasta;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final duracion = hasta.difference(desde).inMilliseconds;
    double posicion(DateTime fecha) => duracion <= 0
        ? 0.5
        : (fecha.difference(desde).inMilliseconds / duracion).clamp(0.0, 1.0);
    final estiloFecha = tipografia.ayuda.copyWith(
      color: colores.textoSecundario,
    );

    return Column(
      children: [
        SizedBox(
          height: Medidas.altoGrafico,
          width: double.infinity,
          child: CustomPaint(
            painter: PintorLineaPuntaje(
              valores: [
                for (final punto in puntos)
                  (posicion(punto.fecha), punto.drivescore),
              ],
              colores: colores,
              estiloGuia: tipografia.ayuda.copyWith(
                color: colores.textoTerciario,
              ),
            ),
          ),
        ),
        const SizedBox(height: Espacios.xs),
        Row(
          children: [
            Text(FormatoViaje.fechaCorta(desde), style: estiloFecha),
            const Spacer(),
            Text(
              FormatoViaje.fechaCorta(desde.add(hasta.difference(desde) ~/ 2)),
              style: estiloFecha,
            ),
            const Spacer(),
            Text('Hoy', style: estiloFecha),
          ],
        ),
      ],
    );
  }
}

/// Dibuja la línea del DriveScore. [valores]: (posición horizontal 0–1,
/// puntaje 0–100), en orden. La línea y el relleno son caminos (`drawPath`);
/// los puntos, círculos; las guías punteadas en 90, 75 y 60, segmentos
/// (`drawLine`) con su número.
class PintorLineaPuntaje extends CustomPainter {
  PintorLineaPuntaje({
    required this.valores,
    required this.colores,
    required this.estiloGuia,
  });

  final List<(double, int)> valores;
  final ColoresDriveSense colores;
  final TextStyle estiloGuia;

  static const _lineasGuia = [90, 75, 60];
  static const _guion = 4.0;
  static const _espacio = 4.0;
  static const _trazo = 3.0;

  /// Espacio a la derecha para el número de las guías.
  static const _margenGuias = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;

    // Escala vertical: hasta 100 y, abajo, 5 bajo el menor (60 o menos)
    final minimo = math.min(55, valores.map((v) => v.$2).reduce(math.min) - 5);
    const radio = Medidas.puntoGraficoUltimo / 2;
    final ancho = size.width - _margenGuias - 2 * radio;
    final alto = size.height - 2 * radio;
    double y(num puntaje) => radio + (100 - puntaje) / (100 - minimo) * alto;
    Offset punto((double, int) valor) =>
        Offset(radio + valor.$1 * ancho, y(valor.$2));

    final pinturaGuia = Paint()
      ..color = colores.borde
      ..strokeWidth = 1;
    for (final guia in _lineasGuia) {
      final yGuia = y(guia);
      for (var x = 0.0; x < radio * 2 + ancho; x += _guion + _espacio) {
        canvas.drawLine(
          Offset(x, yGuia),
          Offset(x + _guion, yGuia),
          pinturaGuia,
        );
      }
      final texto = TextPainter(
        text: TextSpan(text: '$guia', style: estiloGuia),
        textDirection: TextDirection.ltr,
      )..layout();
      texto.paint(
        canvas,
        Offset(size.width - texto.width, yGuia - texto.height / 2),
      );
    }

    final puntos = valores.map(punto).toList();
    final area = Rect.fromLTWH(0, 0, size.width, size.height);
    if (puntos.length > 1) {
      final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (final p in puntos.skip(1)) {
        linea.lineTo(p.dx, p.dy);
      }
      final relleno = Path.from(linea)
        ..lineTo(puntos.last.dx, size.height)
        ..lineTo(puntos.first.dx, size.height)
        ..close();
      canvas.drawPath(
        relleno,
        Paint()..shader = colores.gradienteRellenoGrafica.createShader(area),
      );
      canvas.drawPath(
        linea,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _trazo
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = colores.gradienteScore.createShader(area),
      );
    }

    for (final p in puntos.take(puntos.length - 1)) {
      canvas.drawCircle(
        p,
        Medidas.puntoGrafico / 2,
        Paint()..color = colores.superficie,
      );
      canvas.drawCircle(
        p,
        Medidas.puntoGrafico / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colores.primario,
      );
    }
    // El último (o el único) se resalta
    canvas.drawCircle(
      puntos.last,
      radio,
      Paint()..color = colores.gradienteScore.colors.last,
    );
  }

  @override
  bool shouldRepaint(PintorLineaPuntaje oldDelegate) =>
      oldDelegate.valores != valores ||
      oldDelegate.colores != colores ||
      oldDelegate.estiloGuia != estiloGuia;
}
