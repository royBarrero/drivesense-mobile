import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/design/design.dart';
import '../../../recorridos/presentation/widgets/location_permission_flow.dart';

enum TipoRecorrido { libre, conDestino }

/// "Iniciar recorrido" de Inicio y de Viajes vacío (HU-30): pregunta si el
/// viaje es libre (como siempre) o con destino (Copiloto).
///
/// Libre inicia el viaje enseguida (`iniciarViaje`, que lanza `ErrorRecorrido`
/// si no se pudo); con destino prepara la ubicación y abre el Copiloto.
Future<void> iniciarRecorrido(BuildContext context, WidgetRef ref) async {
  final tipo = await showModalBottomSheet<TipoRecorrido>(
    context: context,
    // Por encima de la barra inferior
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const HojaTipoRecorrido(),
  );
  if (tipo == null || !context.mounted) return;
  switch (tipo) {
    case TipoRecorrido.libre:
      await iniciarViaje(context, ref);
    case TipoRecorrido.conDestino:
      if (!await prepararUbicacion(context, ref)) return;
      if (context.mounted) await context.push(Rutas.copiloto);
  }
}

/// Hoja "¿Cómo quieres viajar?" con las dos opciones.
class HojaTipoRecorrido extends StatelessWidget {
  const HojaTipoRecorrido({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
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
              '¿Cómo quieres viajar?',
              style: context.tipografia.subtituloGrande.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
            const SizedBox(height: Espacios.l),
            _Opcion(
              icono: Icons.play_arrow_rounded,
              fondoIcono: colores.tintePrimario,
              colorIcono: colores.primarioOscuro,
              titulo: 'Recorrido libre',
              texto: 'Registra el viaje sin ruta, como siempre.',
              alPresionar: () => Navigator.pop(context, TipoRecorrido.libre),
            ),
            const SizedBox(height: Espacios.s),
            _Opcion(
              icono: Icons.flag_rounded,
              fondoIcono: colores.tinteSecundario,
              colorIcono: colores.textoEventoVelocidad,
              titulo: 'Con destino',
              capsula: true,
              texto: 'Elige a dónde vas y mira la ruta antes de salir.',
              alPresionar: () =>
                  Navigator.pop(context, TipoRecorrido.conDestino),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.fondoIcono,
    required this.colorIcono,
    required this.titulo,
    required this.texto,
    required this.alPresionar,
    this.capsula = false,
  });

  final IconData icono;
  final Color fondoIcono;
  final Color colorIcono;
  final String titulo;
  final String texto;
  final VoidCallback alPresionar;

  /// Muestra la cápsula "Copiloto" junto al título.
  final bool capsula;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radios.micro),
      side: BorderSide(color: colores.borde),
    );
    return Material(
      color: colores.superficie,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(Espacios.m),
          child: Row(
            children: [
              Container(
                width: Medidas.cajaIconoFila,
                height: Medidas.cajaIconoFila,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(Radios.cajaIcono),
                ),
                child: Icon(icono, size: Medidas.icono, color: colorIcono),
              ),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Espacios.xs,
                      runSpacing: Espacios.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          titulo,
                          style: tipografia.subtitulo.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colores.textoPrincipal,
                          ),
                        ),
                        if (capsula) const CapsulaCopiloto(),
                      ],
                    ),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      texto,
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espacios.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: Medidas.iconoNavegacion,
                color: colores.textoSecundario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cápsula "COPILOTO" (como "Con IA", en cian).
class CapsulaCopiloto extends StatelessWidget {
  const CapsulaCopiloto({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.xs,
        vertical: Espacios.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: colores.tinteSecundario,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Text(
        'COPILOTO',
        style: context.tipografia.etiqueta.copyWith(
          color: colores.textoEventoVelocidad,
        ),
      ),
    );
  }
}
