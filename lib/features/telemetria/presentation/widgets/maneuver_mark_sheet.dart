import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../data/calibration_recorder.dart';
import '../../models/calibration_mark.dart';

/// Botón "Marcar maniobra" del modo calibración (solo en la versión de
/// desarrollo). Grande para tocarlo con una mano mientras se maneja.
class BotonMarcarManiobra extends ConsumerWidget {
  const BotonMarcarManiobra({super.key});

  Future<void> _marcar(BuildContext context, WidgetRef ref) async {
    // El instante es el del toque, no el de elegir la opción (1-2 s después):
    // queda más cerca de la maniobra
    final instante = DateTime.now();
    HapticFeedback.mediumImpact();
    final tipo = await showModalBottomSheet<TipoMarca>(
      context: context,
      builder: (_) => const _OpcionesMarca(),
    );
    if (tipo == null || !context.mounted) return;

    ref.read(registroCalibracionProvider).marca(tipo, instante);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Marcado: ${tipo.texto}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    return SizedBox(
      height: Medidas.altoBotonMarca,
      child: FloatingActionButton.extended(
        onPressed: () => _marcar(context, ref),
        backgroundColor: colores.encabezadoAcento,
        foregroundColor: colores.sobreAcentoOscuro,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.flag_rounded, size: Medidas.iconoNavegacion),
        label: Text('Marcar maniobra', style: context.tipografia.boton),
      ),
    );
  }
}

/// Hoja inferior con las maniobras; devuelve la elegida.
class _OpcionesMarca extends StatelessWidget {
  const _OpcionesMarca();

  @override
  Widget build(BuildContext context) {
    final tipografia = context.tipografia;
    final opciones = [
      for (final tipo in TipoMarca.values) _OpcionMarca(tipo: tipo),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacios.l,
          0,
          Espacios.l,
          Espacios.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Qué maniobra fue?',
              style: tipografia.subtitulo.copyWith(
                color: context.colores.textoPrincipal,
              ),
            ),
            // Dos columnas, de a dos en orden; si la última fila queda con una
            // sola opción, ocupa media fila como las demás
            for (var i = 0; i < opciones.length; i += 2) ...[
              SizedBox(height: i == 0 ? Espacios.m : Espacios.s),
              Row(
                children: [
                  Expanded(child: opciones[i]),
                  const SizedBox(width: Espacios.s),
                  Expanded(
                    child: i + 1 < opciones.length
                        ? opciones[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpcionMarca extends StatelessWidget {
  const _OpcionMarca({required this.tipo});

  final TipoMarca tipo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final (tinte, color) = switch (tipo) {
      TipoMarca.frenadaFuerte => (colores.tintePeligro, colores.textoPeligro),
      TipoMarca.aceleracionFuerte => (colores.tinteConfort, colores.confort),
      TipoMarca.giroBrusco => (colores.tinteAdvertencia, colores.advertencia),
      TipoMarca.bache => (colores.tinteSecundario, colores.secundario),
      TipoMarca.telefonoMovido => (
        colores.tintePrimario,
        colores.primarioOscuro,
      ),
    };

    return Material(
      color: tinte,
      borderRadius: BorderRadius.circular(Radios.micro),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, tipo),
        child: SizedBox(
          height: Medidas.altoOpcionMarca,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tipo.icono, size: Medidas.iconoNavegacion, color: color),
              const SizedBox(height: Espacios.xs),
              Text(
                tipo.texto,
                textAlign: TextAlign.center,
                style: context.tipografia.subtitulo.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
