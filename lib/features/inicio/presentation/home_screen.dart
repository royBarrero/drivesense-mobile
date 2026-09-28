import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/accent_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/illustration_painters.dart';
import '../../../core/widgets/label.dart';
import '../../../core/widgets/logo.dart';
import '../../auth/providers/session_provider.dart';
import '../../recorridos/presentation/trip_format.dart';
import '../../recorridos/presentation/widgets/location_permission_flow.dart';
import '../../recorridos/providers/pending_summary_provider.dart';
import '../../recorridos/providers/trip_provider.dart';

/// Pestaña Inicio: saludo, tarjeta del recorrido y espacio del DriveScore.
class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final nombre = ref.watch(sesionProvider).value?.nombre ?? '';
    final hayPendiente = ref.watch(resumenPendienteProvider).value != null;
    final primerNombre = nombre.split(' ').first;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Espacios.l,
          Espacios.m,
          Espacios.l,
          MediaQuery.paddingOf(context).bottom + Espacios.l,
        ),
        children: [
          Row(
            children: [
              const LogoDriveSense(compacto: true),
              const Spacer(),
              Avatar(nombre: nombre),
            ],
          ),
          const SizedBox(height: Espacios.xl),
          Text(
            'Hola, $primerNombre',
            style: tipografia.tituloGrande.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            'Listo para un viaje seguro hoy.',
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          const SizedBox(height: Espacios.xl),
          const _TarjetaRecorrido(),
          if (hayPendiente) ...[
            const SizedBox(height: Espacios.m),
            const _AvisoPendiente(),
          ],
          const SizedBox(height: Espacios.m),
          const _TarjetaDriveScore(),
        ],
      ),
    );
  }
}

/// Tarjeta oscura del recorrido: iniciar, volver al viaje en curso, o
/// continuar/finalizar uno interrumpido. Mientras hay un viaje no se puede
/// iniciar otro.
class _TarjetaRecorrido extends ConsumerStatefulWidget {
  const _TarjetaRecorrido();

  @override
  ConsumerState<_TarjetaRecorrido> createState() => _TarjetaRecorridoState();
}

class _TarjetaRecorridoState extends ConsumerState<_TarjetaRecorrido> {
  bool _ocupado = false;
  String? _error;

  /// Ejecuta una acción mostrando el indicador y su error, si lo hay.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on ErrorRecorrido catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _iniciar() => _ejecutar(() async {
    if (!await prepararUbicacion(context, ref)) return;
    await ref.read(viajeProvider.notifier).iniciar();
    if (mounted) context.push(Rutas.recorrido);
  });

  Future<void> _continuar() => _ejecutar(() async {
    if (!await prepararUbicacion(context, ref)) return;
    ref.read(viajeProvider.notifier).continuar();
    if (mounted) context.push(Rutas.recorrido);
  });

  Future<void> _finalizar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Finalizar el viaje?'),
        content: const Text(
          'Se guardará con lo registrado hasta que se cerró la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _ejecutar(() async {
      await ref.read(viajeProvider.notifier).finalizar();
      if (mounted) context.go(Rutas.resumenRecorrido);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estado = ref.watch(viajeProvider);
    final viaje = estado.value;

    final (String etiqueta, String titulo, String texto) = switch (viaje) {
      ViajeEnCurso() => (
        'Registrando',
        'Viaje en curso',
        '${FormatoViaje.kilometros(viaje.distanciaM)} km · '
            '${FormatoViaje.duracion(viaje.duracionS)}',
      ),
      ViajeInterrumpido() => (
        'Viaje sin terminar',
        'Tienes un viaje sin terminar',
        'Lo iniciaste ${_cuando(viaje.viaje.acumulador.inicio)}. '
            '¿Quieres continuarlo o finalizarlo?',
      ),
      _ => (
        'Nuevo recorrido',
        '¿Listo para salir?',
        'Mediremos tu velocidad, el tiempo y la distancia mientras conduces.',
      ),
    };

    final List<Widget> botones = switch (viaje) {
      ViajeEnCurso() => [
        BotonAcento(
          texto: 'Volver al viaje',
          icono: Icons.navigation_rounded,
          alPresionar: () => context.push(Rutas.recorrido),
        ),
      ],
      ViajeInterrumpido() => [
        BotonAcento(
          texto: 'Continuar viaje',
          icono: Icons.play_arrow_rounded,
          cargando: _ocupado,
          alPresionar: _continuar,
        ),
        const SizedBox(height: Espacios.s),
        OutlinedButton(
          onPressed: _ocupado ? null : _finalizar,
          // Variante contorno sobre el fondo oscuro
          style: OutlinedButton.styleFrom(
            foregroundColor: colores.encabezadoTexto,
            side: BorderSide(color: colores.encabezadoBorde),
          ),
          child: const Text('Finalizar'),
        ),
      ],
      _ => [
        BotonAcento(
          texto: 'Iniciar recorrido',
          icono: Icons.play_arrow_rounded,
          // Mientras se consulta si hay un viaje en curso no se puede iniciar
          cargando: _ocupado || estado.isLoading,
          alPresionar: _iniciar,
        ),
      ],
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radios.tarjetaDestacada),
      child: ColoredBox(
        color: colores.encabezadoFondo,
        child: Stack(
          children: [
            // Diana recortada en la esquina superior derecha
            Positioned(
              top: -_ladoDiana / 3,
              right: -_ladoDiana / 3,
              width: _ladoDiana,
              height: _ladoDiana,
              child: CustomPaint(
                painter: CirculosReducidosPainter(
                  colorLineas: colores.encabezadoBorde,
                  escala: 2.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Espacios.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Etiqueta(
                    etiqueta,
                    grande: true,
                    color: colores.encabezadoAcento,
                  ),
                  const SizedBox(height: Espacios.s),
                  Text(
                    titulo,
                    style: tipografia.tituloTarjeta.copyWith(
                      color: colores.encabezadoTexto,
                    ),
                  ),
                  const SizedBox(height: Espacios.xs),
                  Text(
                    texto,
                    style: tipografia.cuerpo.copyWith(
                      color: colores.encabezadoTextoSecundario,
                    ),
                  ),
                  const SizedBox(height: Espacios.xl),
                  if (_error != null) ...[
                    AvisoError(mensaje: _error!),
                    const SizedBox(height: Espacios.m),
                  ],
                  ...botones,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lado del área de la diana (sus ejes miden 44 × escala a cada lado).
  static const _ladoDiana = 220.0;

  /// "hoy a las 08:05" o "el 26/09 a las 18:40".
  static String _cuando(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final local = fecha.toLocal();
    final ahora = DateTime.now();
    final hora = '${dos(local.hour)}:${dos(local.minute)}';
    final esHoy =
        local.year == ahora.year &&
        local.month == ahora.month &&
        local.day == ahora.day;
    return esHoy
        ? 'hoy a las $hora'
        : 'el ${dos(local.day)}/${dos(local.month)} a las $hora';
  }
}

class _AvisoPendiente extends StatelessWidget {
  const _AvisoPendiente();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.all(Espacios.s),
      decoration: BoxDecoration(
        color: colores.tinteAdvertencia,
        borderRadius: BorderRadius.circular(Radios.campo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: Medidas.icono,
            color: colores.advertencia,
          ),
          const SizedBox(width: Espacios.xs),
          Expanded(
            child: Text(
              'Tienes un viaje pendiente de envío. Se enviará automáticamente '
              'cuando haya conexión.',
              style: context.tipografia.cuerpoPequeno.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Espacio del DriveScore: sin datos todavía (se calcula en la HU-15).
class _TarjetaDriveScore extends StatelessWidget {
  const _TarjetaDriveScore();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      padding: const EdgeInsets.all(Espacios.l),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: Medidas.anilloInicio,
            child: CustomPaint(
              painter: _AnilloVacio(colores.carril),
              child: Center(
                child: Text(
                  '—',
                  style: tipografia.puntaje.copyWith(
                    color: colores.textoTerciario,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Espacios.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu DriveScore',
                  style: tipografia.subtitulo.copyWith(
                    color: colores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: Espacios.xxs),
                Text(
                  'Tu DriveScore aparecerá aquí después de tus primeros viajes',
                  style: tipografia.cuerpoPequeno.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carril del anillo de DriveScore, sin progreso (docs/diseno.md, 7).
class _AnilloVacio extends CustomPainter {
  _AnilloVacio(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const trazo = Medidas.trazoAnilloPequeno;
    canvas.drawCircle(
      size.center(Offset.zero),
      (size.shortestSide - trazo) / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = trazo,
    );
  }

  @override
  bool shouldRepaint(_AnilloVacio oldDelegate) => oldDelegate.color != color;
}
