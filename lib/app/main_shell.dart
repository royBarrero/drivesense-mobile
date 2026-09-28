import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/design/design.dart';
import '../core/platform/system_navigation.dart';

/// Estructura principal con la barra de navegación inferior: Inicio, Viajes y Perfil.
class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key, required this.navegacion});

  final StatefulNavigationShell navegacion;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // "Atrás" en una pestaña: la app pasa al fondo en vez de cerrarse
      // (cerrarla detendría el registro de un viaje en curso)
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) enviarAppAlFondo();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Íconos oscuros en la barra de estado (sin AppBar no se ajustan solos)
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          // El contenido pasa por detrás de la barra para que se vea el desenfoque
          extendBody: true,
          body: navegacion,
          bottomNavigationBar: BarraNavegacion(
            indiceActivo: navegacion.currentIndex,
            // Tocar la pestaña activa la devuelve a su pantalla inicial
            alSeleccionar: (indice) => navegacion.goBranch(
              indice,
              initialLocation: indice == navegacion.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior translúcida (docs/diseno.md, 5).
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({
    super.key,
    required this.indiceActivo,
    required this.alSeleccionar,
  });

  final int indiceActivo;
  final ValueChanged<int> alSeleccionar;

  static const _items = [
    (icono: Icons.home_outlined, activo: Icons.home, texto: 'Inicio'),
    (icono: Icons.route_outlined, activo: Icons.route, texto: 'Viajes'),
    (icono: Icons.person_outline, activo: Icons.person, texto: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colores.barraNavegacion,
            border: Border(top: BorderSide(color: colores.borde)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Espacios.xs),
              child: Row(
                children: [
                  for (final (indice, item) in _items.indexed)
                    Expanded(
                      child: _ItemNavegacion(
                        icono: indice == indiceActivo
                            ? item.activo
                            : item.icono,
                        texto: item.texto,
                        activo: indice == indiceActivo,
                        alPresionar: () => alSeleccionar(indice),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemNavegacion extends StatelessWidget {
  const _ItemNavegacion({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final color = activo ? colores.primarioOscuro : colores.textoTerciario;

    return Semantics(
      button: true,
      selected: activo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alPresionar,
        child: Center(
          // Sin heightFactor se estira a todo el alto: la barra ocuparía la pantalla
          heightFactor: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: Espacios.m,
              vertical: Espacios.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: activo ? colores.tinteNavActivo : null,
              borderRadius: BorderRadius.circular(Radios.pildora),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: Medidas.iconoNavegacion, color: color),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: context.tipografia.ayuda.copyWith(
                    color: color,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
