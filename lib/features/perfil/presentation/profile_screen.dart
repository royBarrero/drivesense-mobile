import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/label.dart';
import '../../auth/providers/session_provider.dart';
import '../../gamificacion/presentation/widgets/level_card.dart';
import '../../recorridos/data/location_service.dart';
import '../../recorridos/providers/trip_provider.dart';
import '../../telemetria/presentation/widgets/learning_toggle.dart';
import '../../telemetria/providers/alert_sound_provider.dart';
import '../../telemetria/providers/calibration_mode_provider.dart';

/// Pestaña Perfil: datos del conductor, su nivel y logros (HU-21) y cierre de
/// sesión.
class PerfilPantalla extends ConsumerWidget {
  const PerfilPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final usuario = ref.watch(sesionProvider).value;
    final viaje = ref.watch(viajeProvider).value;
    // Cerrar sesión detendría el registro del viaje
    final enViaje = viaje is ViajeEnCurso || viaje is ViajeInterrumpido;
    final nombre = usuario?.nombre ?? '';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Espacios.l,
          Espacios.l,
          Espacios.l,
          MediaQuery.paddingOf(context).bottom + Espacios.l,
        ),
        children: [
          Text(
            'Perfil',
            style: tipografia.titulo.copyWith(color: colores.textoPrincipal),
          ),
          const SizedBox(height: Espacios.xl),
          _Tarjeta(
            child: Row(
              children: [
                Avatar(nombre: nombre, grande: true),
                const SizedBox(width: Espacios.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: tipografia.subtituloGrande.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: Espacios.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Espacios.s,
                          vertical: Espacios.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colores.tintePrimario,
                          borderRadius: BorderRadius.circular(Radios.pildora),
                        ),
                        child: Text(
                          // Conductor de flota: el nombre de su empresa
                          usuario?.empresa?.nombre ?? 'Conductor',
                          style: tipografia.cuerpoPequeno.copyWith(
                            color: colores.primarioOscuro,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nivel y logros (HU-21)
          const SizedBox(height: Espacios.m),
          const TarjetaNivel(),
          const SizedBox(height: Espacios.m),
          _Tarjeta(
            child: Column(
              children: [
                _Dato(
                  icono: Icons.mail_outline,
                  etiqueta: 'Correo',
                  valor: usuario?.email ?? '',
                ),
                Divider(height: Espacios.xl, color: colores.bordeFuerte),
                _Dato(
                  icono: Icons.phone_outlined,
                  etiqueta: 'Teléfono',
                  valor: usuario?.telefono ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacios.m),
          const _Tarjeta(child: _SonidoAvisos()),
          const SizedBox(height: Espacios.m),
          const _Tarjeta(child: InterruptorAprendizaje()),
          const SizedBox(height: Espacios.m),
          const _Ayuda(),
          // Solo en la versión de desarrollo (HU-07)
          if (kDebugMode) ...[
            const SizedBox(height: Espacios.m),
            _Tarjeta(child: _ModoCalibracion(enViaje: enViaje)),
          ],
          const SizedBox(height: Espacios.xl),
          OutlinedButton.icon(
            onPressed: enViaje
                ? null
                : () => ref.read(sesionProvider.notifier).cerrarSesion(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colores.textoPeligro,
              side: BorderSide(color: colores.bordePeligroSuave),
            ),
            icon: const Icon(Icons.logout, size: Medidas.icono),
            label: const Text('Cerrar sesión'),
          ),
          if (enViaje) ...[
            const SizedBox(height: Espacios.xs),
            Text(
              'Finaliza el viaje en curso antes de cerrar sesión.',
              textAlign: TextAlign.center,
              style: tipografia.ayuda.copyWith(color: colores.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sonido de los avisos de eventos (HU-14). Silenciado, solo vibra. Se puede
/// cambiar durante el viaje.
class _SonidoAvisos extends ConsumerWidget {
  const _SonidoAvisos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final activo = ref.watch(sonidoAvisosProvider).value ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Etiqueta('Avisos'),
                  const SizedBox(height: Espacios.xxs),
                  Text(
                    'Sonido de avisos',
                    style: context.tipografia.cuerpo.copyWith(
                      color: colores.textoPrincipal,
                    ),
                  ),
                  Text(
                    'La vibración se mantiene aunque lo silencies.',
                    style: context.tipografia.ayuda.copyWith(
                      color: colores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espacios.s),
            Switch(
              value: activo,
              onChanged: (valor) =>
                  ref.read(sonidoAvisosProvider.notifier).cambiar(valor),
            ),
          ],
        ),
        const _AvisoNotificaciones(),
      ],
    );
  }
}

/// Con el permiso de notificaciones negado: no se verán los eventos con la
/// pantalla apagada. Se vuelve a revisar al regresar de los ajustes.
class _AvisoNotificaciones extends ConsumerStatefulWidget {
  const _AvisoNotificaciones();

  @override
  ConsumerState<_AvisoNotificaciones> createState() =>
      _AvisoNotificacionesState();
}

class _AvisoNotificacionesState extends ConsumerState<_AvisoNotificaciones> {
  late final _ciclo = AppLifecycleListener(
    onResume: () => ref.invalidate(notificacionesPermitidasProvider),
  );

  @override
  void initState() {
    super.initState();
    _ciclo;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final permitidas = ref.watch(notificacionesPermitidasProvider).value;
    if (permitidas != false) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Espacios.xs),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: Medidas.icono,
            color: colores.textoSecundario,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              'Notificaciones desactivadas: no verás los avisos con la '
              'pantalla apagada.',
              style: context.tipografia.ayuda.copyWith(
                color: colores.textoSecundario,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(servicioUbicacionProvider).abrirAjustesApp(),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

/// Graba en un CSV los datos crudos del siguiente viaje (sensores y GPS).
class _ModoCalibracion extends ConsumerWidget {
  const _ModoCalibracion({required this.enViaje});

  final bool enViaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final activo = ref.watch(modoCalibracionProvider).value ?? false;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Etiqueta('Desarrollo'),
              const SizedBox(height: Espacios.xxs),
              Text(
                'Modo calibración',
                style: context.tipografia.cuerpo.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              Text(
                enViaje
                    ? 'Se aplica al siguiente viaje.'
                    : 'Graba en un CSV los datos crudos de los sensores y del '
                          'GPS del próximo viaje.',
                style: context.tipografia.ayuda.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espacios.s),
        Switch(
          value: activo,
          // Cambiarlo a mitad de viaje dejaría un CSV incompleto
          onChanged: enViaje
              ? null
              : (valor) =>
                    ref.read(modoCalibracionProvider.notifier).cambiar(valor),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: child,
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Row(
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
              Etiqueta(etiqueta),
              const SizedBox(height: Espacios.xxs),
              Text(
                valor,
                style: context.tipografia.cuerpo.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Abre el asistente de ayuda (docs/diseno.md, 7.1: "Ayuda").
class _Ayuda extends StatelessWidget {
  const _Ayuda();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Material(
      color: colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        side: BorderSide(color: colores.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Rutas.asistente),
        child: Padding(
          padding: const EdgeInsets.all(Espacios.l),
          child: Row(
            children: [
              Container(
                width: Medidas.cajaIconoFila,
                height: Medidas.cajaIconoFila,
                decoration: BoxDecoration(
                  color: colores.tintePrimario,
                  borderRadius: BorderRadius.circular(Radios.cajaIcono),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: Medidas.icono,
                  color: colores.primarioOscuro,
                ),
              ),
              const SizedBox(width: Espacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Etiqueta('Ayuda'),
                    const SizedBox(height: Espacios.xxs),
                    Text(
                      'Asistente de ayuda',
                      style: tipografia.cuerpo.copyWith(
                        color: colores.textoPrincipal,
                      ),
                    ),
                    Text(
                      'Pregunta cómo usar la app',
                      style: tipografia.ayuda.copyWith(
                        color: colores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
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
