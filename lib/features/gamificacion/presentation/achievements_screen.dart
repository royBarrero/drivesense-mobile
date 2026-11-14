import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/screen_header.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/load_error.dart';
import '../models/progress.dart';
import '../providers/progress_provider.dart';
import 'widgets/achievement_widgets.dart';

/// Logros del conductor (HU-21): resumen, desbloqueados con su fecha y
/// pendientes con lo que falta. Se abre desde Perfil.
class LogrosPantalla extends ConsumerWidget {
  const LogrosPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final estado = ref.watch(progresoProvider);
    final progreso = estado.value;

    final List<Widget> contenido;
    if (estado.hasError && !estado.isLoading) {
      contenido = [
        Padding(
          padding: const EdgeInsets.only(top: Espacios.xxl),
          child: ErrorCarga(
            error: estado.error!,
            alReintentar: () => ref.invalidate(progresoProvider),
          ),
        ),
      ];
    } else if (progreso == null) {
      contenido = const [
        Padding(
          padding: EdgeInsets.only(top: Espacios.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else {
      final desbloqueados = [
        for (final logro in progreso.logros)
          if (logro.desbloqueado) logro,
      ];
      final pendientes = [
        for (final logro in progreso.logros)
          if (!logro.desbloqueado) logro,
      ];
      contenido = [
        _TarjetaResumen(progreso: progreso),
        if (desbloqueados.isNotEmpty) ...[
          const SizedBox(height: Espacios.l),
          const Etiqueta('Desbloqueados'),
          const SizedBox(height: Espacios.s),
          _Lista(logros: desbloqueados),
        ],
        if (pendientes.isNotEmpty) ...[
          const SizedBox(height: Espacios.l),
          const Etiqueta('Pendientes'),
          const SizedBox(height: Espacios.s),
          _Lista(logros: pendientes),
        ],
      ];
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.fondo,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Espacios.l,
              Espacios.m,
              Espacios.l,
              MediaQuery.paddingOf(context).bottom + Espacios.l,
            ),
            children: [
              const CabeceraPantalla(
                titulo: 'Logros',
                alternativa: Rutas.perfil,
              ),
              const SizedBox(height: Espacios.l),
              ...contenido,
            ],
          ),
        ),
      ),
    );
  }
}

/// "4 de 9 desbloqueados" con su barra.
class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.progreso});

  final ProgresoConductor progreso;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final total = progreso.logros.length;
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: decoracionTarjeta(colores),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${progreso.desbloqueados}',
                style: tipografia.puntaje.copyWith(
                  color: colores.textoPrincipal,
                ),
              ),
              const SizedBox(width: Espacios.xs),
              Expanded(
                child: Text(
                  'de $total desbloqueados',
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacios.s),
          BarraProgreso(valor: total == 0 ? 0 : progreso.desbloqueados / total),
        ],
      ),
    );
  }
}

/// Una tarjeta con una fila por logro, separadas por una línea.
class _Lista extends StatelessWidget {
  const _Lista({required this.logros});

  final List<Logro> logros;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.m,
        vertical: Espacios.xs,
      ),
      decoration: decoracionTarjeta(colores),
      child: Column(
        children: [
          for (final (i, logro) in logros.indexed) ...[
            if (i > 0) Divider(height: 1, color: colores.borde),
            _FilaLogro(logro: logro),
          ],
        ],
      ),
    );
  }
}

class _FilaLogro extends StatelessWidget {
  const _FilaLogro({required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final fecha = logro.fechaDesbloqueo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacios.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CajaLogro(codigo: logro.codigo, desbloqueado: logro.desbloqueado),
          const SizedBox(width: Espacios.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logro.nombre,
                  style: tipografia.cuerpo.copyWith(
                    color: logro.desbloqueado
                        ? colores.textoPrincipal
                        : colores.textoSecundario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Espacios.xxs),
                Text(
                  logro.descripcion,
                  style: tipografia.cuerpoPequeno.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
                const SizedBox(height: Espacios.xs),
                if (logro.desbloqueado && fecha != null)
                  Text(
                    'Desbloqueado el ${FormatoViaje.diaMes(fecha)}',
                    style: tipografia.ayuda.copyWith(
                      color: colores.primarioOscuro,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (!logro.desbloqueado) ...[
                  // Los de un solo viaje no tienen avance parcial
                  if (logro.tipo != TipoProgreso.viaje) ...[
                    BarraProgreso(
                      valor: logro.progreso / logro.meta,
                      color: colores.textoTerciario,
                    ),
                    const SizedBox(height: Espacios.xxs),
                  ],
                  Text(
                    logro.faltante,
                    style: tipografia.ayuda.copyWith(
                      color: colores.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
