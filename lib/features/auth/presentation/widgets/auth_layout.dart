import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/design.dart';
import 'auth_header.dart';

export 'auth_header.dart' show IlustracionEncabezado;

/// Estructura común de login y registro (docs/diseno.md, 4.2): encabezado oscuro,
/// tarjeta superpuesta y pie, dentro de un scroll.
///
/// La barra de estado queda siempre sobre una franja fija del color del
/// encabezado, y el scroll empieza debajo de ella: así el contenido nunca pasa
/// por detrás de la hora ni de los íconos, tampoco al desplazarse con el teclado.
class PantallaAuth extends StatelessWidget {
  const PantallaAuth({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.tarjeta,
    required this.pie,
    this.altoEncabezado,
    this.alVolver,
    this.ilustracion = IlustracionEncabezado.completa,
  });

  final String titulo;
  final String subtitulo;
  final Widget tarjeta;
  final Widget pie;

  /// Alto total del bloque oscuro, incluida la barra de estado.
  /// Nulo: se ajusta al contenido, con mínimo [Medidas.altoMinimoEncabezadoRegistro].
  final double? altoEncabezado;
  final VoidCallback? alVolver;
  final IlustracionEncabezado ilustracion;

  @override
  Widget build(BuildContext context) {
    final barraEstado = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos claros: la franja bajo la barra de estado siempre es oscura
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: barraEstado,
              width: double.infinity,
              child: ColoredBox(color: context.colores.encabezadoFondo),
            ),
            Expanded(
              // La franja ya ocupa la barra de estado: el contenido no la reserva otra vez
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    children: [
                      EncabezadoAuth(
                        titulo: titulo,
                        subtitulo: subtitulo,
                        // Los altos del diseño incluyen la barra de estado
                        alto: altoEncabezado == null
                            ? null
                            : altoEncabezado! - barraEstado,
                        altoMinimo:
                            Medidas.altoMinimoEncabezadoRegistro - barraEstado,
                        alVolver: alVolver,
                        ilustracion: ilustracion,
                      ),
                      // La tarjeta sube sobre el encabezado
                      Transform.translate(
                        offset: const Offset(0, -Medidas.superposicionTarjeta),
                        child: Column(
                          children: [
                            tarjeta,
                            const SizedBox(height: Espacios.l),
                            pie,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
