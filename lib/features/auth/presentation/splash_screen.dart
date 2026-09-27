import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/logo.dart';
import '../providers/session_provider.dart';

/// Se muestra mientras se comprueba el token guardado (`GET /auth/yo`).
/// Si no se pudo comprobar (p. ej. sin conexión), ofrece reintentar.
class ArranquePantalla extends ConsumerWidget {
  const ArranquePantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final sesion = ref.watch(sesionProvider);
    final error = sesion.hasError && !sesion.isLoading ? sesion.error : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colores.encabezadoFondo,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacios.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoDriveSense(),
                const SizedBox(height: Espacios.xxl),
                if (error == null)
                  SizedBox.square(
                    dimension: Medidas.iconoNavegacion,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colores.encabezadoAcento,
                    ),
                  )
                else ...[
                  Text(
                    error is ErrorApi ? error.mensaje : ErrorApi.inesperado,
                    textAlign: TextAlign.center,
                    style: context.tipografia.cuerpo.copyWith(
                      color: colores.encabezadoTextoSecundario,
                    ),
                  ),
                  const SizedBox(height: Espacios.l),
                  FilledButton(
                    onPressed: () =>
                        ref.read(sesionProvider.notifier).reintentar(),
                    child: const Text('Reintentar'),
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
