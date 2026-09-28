import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/label.dart';
import '../../auth/providers/session_provider.dart';
import '../../recorridos/providers/trip_provider.dart';

/// Pestaña Perfil: datos del conductor y cierre de sesión.
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
