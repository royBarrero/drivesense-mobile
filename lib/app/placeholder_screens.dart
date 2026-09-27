import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/design.dart';
import '../core/widgets/primary_button.dart';
import '../features/auth/providers/session_provider.dart';

// Pantallas provisionales: se reemplazan al implementar sus historias.

/// Inicio provisional: saludo y cierre de sesión.
class InicioProvisionalPantalla extends ConsumerWidget {
  const InicioProvisionalPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos oscuros en la barra de estado (sin AppBar no se ajustan solos)
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Espacios.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hola, ${usuario?.nombre ?? ''}',
                  style: context.tipografia.titulo.copyWith(
                    color: context.colores.textoPrincipal,
                  ),
                ),
                const Spacer(),
                BotonPrimario(
                  texto: 'Cerrar sesión',
                  alPresionar: () =>
                      ref.read(sesionProvider.notifier).cerrarSesion(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cambio de contraseña temporal: se implementa en otra historia.
class CambioContraseniaProvisionalPantalla extends ConsumerWidget {
  const CambioContraseniaProvisionalPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PantallaTexto(
      titulo: 'Cambio de contraseña',
      // Sin esto el usuario quedaría atrapado aquí: la ruta lo trae siempre de vuelta
      accion: TextButton(
        onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
        child: const Text('Cerrar sesión'),
      ),
    );
  }
}

class _PantallaTexto extends StatelessWidget {
  const _PantallaTexto({required this.titulo, this.accion});

  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: context.colores.fondo),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: context.tipografia.titulo.copyWith(
                color: context.colores.textoPrincipal,
              ),
            ),
            ?accion,
          ],
        ),
      ),
    );
  }
}
