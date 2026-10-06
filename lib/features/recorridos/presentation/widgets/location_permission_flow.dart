import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/location_service.dart';
import '../../providers/trip_provider.dart';

/// Prepara la ubicación, inicia un viaje y abre la pantalla en vivo (Inicio y
/// Viajes sin viajes). Lanza `ErrorRecorrido` si no se pudo iniciar.
Future<void> iniciarViaje(BuildContext context, WidgetRef ref) async {
  if (!await prepararUbicacion(context, ref)) return;
  await ref.read(viajeProvider.notifier).iniciar();
  if (context.mounted) context.push(Rutas.recorrido);
}

/// Prepara permisos y GPS antes de iniciar o continuar un viaje.
///
/// Si faltan permisos, primero explica para qué son. Devuelve `true` si se
/// puede empezar a registrar.
Future<bool> prepararUbicacion(BuildContext context, WidgetRef ref) async {
  final servicio = ref.read(servicioUbicacionProvider);

  if (!await servicio.permisosConcedidos()) {
    if (!context.mounted) return false;
    final aceptado = await showModalBottomSheet<bool>(
      context: context,
      // Por encima de la barra inferior
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _ExplicacionPermisos(),
    );
    if (aceptado != true) return false;
  }

  final estado = await servicio.preparar();
  if (!context.mounted) return false;
  switch (estado) {
    case EstadoUbicacion.lista:
      return true;
    case EstadoUbicacion.permisoDenegado:
      await _avisar(
        context,
        titulo: 'Sin permiso de ubicación',
        mensaje:
            'Sin acceso a la ubicación no se puede medir el viaje. '
            'Puedes volver a intentarlo cuando quieras.',
      );
    case EstadoUbicacion.permisoBloqueado:
      await _avisar(
        context,
        titulo: 'Permiso de ubicación desactivado',
        mensaje:
            'Actívalo en los ajustes de la app, en Permisos > Ubicación > '
            'Permitir solo mientras se usa la app.',
        accion: 'Abrir ajustes',
        alAceptar: servicio.abrirAjustesApp,
      );
    case EstadoUbicacion.gpsApagado:
      await _avisar(
        context,
        titulo: 'Ubicación apagada',
        mensaje: 'Enciende la ubicación del teléfono para registrar el viaje.',
        accion: 'Activar ubicación',
        alAceptar: servicio.abrirAjustesUbicacion,
      );
  }
  return false;
}

Future<void> _avisar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String? accion,
  Future<void> Function()? alAceptar,
}) {
  return showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: Text(accion == null ? 'Entendido' : 'Ahora no'),
        ),
        if (accion != null)
          TextButton(
            onPressed: () {
              Navigator.pop(contexto);
              alAceptar?.call();
            },
            child: Text(accion),
          ),
      ],
    ),
  );
}

/// Hoja inferior que explica los permisos antes de pedirlos.
class _ExplicacionPermisos extends StatelessWidget {
  const _ExplicacionPermisos();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

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
              'Antes de empezar',
              style: tipografia.subtituloGrande.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
            const SizedBox(height: Espacios.l),
            const _Motivo(
              icono: Icons.location_on_outlined,
              titulo: 'Ubicación',
              texto:
                  'Para medir tu velocidad, el tiempo y la distancia del viaje. '
                  'Solo se usa mientras registras un recorrido.',
            ),
            const SizedBox(height: Espacios.m),
            const _Motivo(
              icono: Icons.notifications_none,
              titulo: 'Notificaciones',
              texto:
                  'Para mostrar un aviso fijo mientras el viaje se registra, '
                  'también con la pantalla apagada.',
            ),
            const SizedBox(height: Espacios.xl),
            BotonPrimario(
              texto: 'Continuar',
              alPresionar: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: Espacios.xs),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Motivo extends StatelessWidget {
  const _Motivo({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: Medidas.cajaIcono,
          height: Medidas.cajaIcono,
          decoration: BoxDecoration(
            color: colores.tintePrimario,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(
            icono,
            size: Medidas.icono,
            color: colores.primarioOscuro,
          ),
        ),
        const SizedBox(width: Espacios.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: tipografia.subtitulo.copyWith(
                  color: colores.textoPrincipal,
                ),
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
      ],
    );
  }
}
