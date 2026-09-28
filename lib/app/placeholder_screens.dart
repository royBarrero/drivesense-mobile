import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/design.dart';
import '../features/auth/providers/session_provider.dart';

// Pantallas provisionales: se reemplazan al implementar sus historias.

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
