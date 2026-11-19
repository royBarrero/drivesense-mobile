import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/api/api_error.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../recorridos/data/location_service.dart';
import '../../recorridos/presentation/widgets/location_permission_flow.dart';
import '../../recorridos/presentation/widgets/map_button.dart';
import '../../recorridos/presentation/widgets/trip_map.dart';
import '../../recorridos/providers/trip_provider.dart';
import '../../telemetria/presentation/widgets/learning_toggle.dart';
import '../models/route_plan.dart';
import '../providers/navigation_provider.dart';
import 'route_format.dart';
import 'widgets/place_search_sheet.dart';
import 'widgets/route_steps_sheet.dart';

/// Lo que tapa la tarjeta de abajo al encuadrar la ruta (alto aproximado, con la
/// ruta y el Modo aprendizaje; medido en el A34).
const _altoTarjeta = 320.0;

/// Copiloto, paso 1 (HU-30): elegir el destino (tocando el mapa o buscándolo
/// por nombre), ver la ruta en auto con su distancia, tiempo y pasos, e iniciar
/// el recorrido con ese destino. Sin ruta o sin conexión, ofrece un recorrido
/// libre.
class CopilotoPantalla extends ConsumerStatefulWidget {
  const CopilotoPantalla({super.key});

  @override
  ConsumerState<CopilotoPantalla> createState() => _CopilotoPantallaState();
}

class _CopilotoPantallaState extends ConsumerState<CopilotoPantalla> {
  final _mapa = ControladorMapaDestino();

  Coordenada? _ubicacion;
  bool _sinUbicacion = false;
  Destino? _destino;

  bool _iniciando = false;
  String? _errorInicio;

  @override
  void initState() {
    super.initState();
    _ubicar();
  }

  Future<void> _ubicar() async {
    setState(() => _sinUbicacion = false);
    try {
      final lectura = await ref
          .read(servicioUbicacionProvider)
          .posicionActual();
      if (!mounted) return;
      setState(
        () => _ubicacion = Coordenada(lectura.latitud, lectura.longitud),
      );
    } catch (_) {
      if (mounted) setState(() => _sinUbicacion = true);
    }
  }

  void _elegir(Destino destino) {
    HapticFeedback.selectionClick();
    setState(() {
      _destino = destino;
      _errorInicio = null;
    });
  }

  void _quitarDestino() => setState(() {
    _destino = null;
    _errorInicio = null;
  });

  Future<void> _buscar() async {
    final lugar = await buscarDestino(context);
    if (lugar != null && mounted) _elegir(Destino.deLugar(lugar));
  }

  /// Inicia el viaje (con [destino] o libre) y reemplaza esta pantalla por la
  /// del viaje en vivo: "Atrás" desde ahí vuelve a Inicio.
  Future<void> _iniciar(Destino? destino, {RutaPlaneada? ruta}) async {
    if (_iniciando) return;
    setState(() {
      _iniciando = true;
      _errorInicio = null;
    });
    try {
      if (!await prepararUbicacion(context, ref)) return;
      await ref
          .read(viajeProvider.notifier)
          .iniciar(destino: destino, ruta: ruta);
      if (mounted) context.pushReplacement(Rutas.recorrido);
    } on ErrorRecorrido catch (e) {
      if (mounted) setState(() => _errorInicio = e.mensaje);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final ubicacion = _ubicacion;
    final destino = _destino;
    final ruta = ubicacion == null || destino == null
        ? null
        : ref.watch(rutaPlaneadaProvider((ubicacion, destino.posicion)));
    final margen = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.superficieAlt,
        body: Stack(
          children: [
            Positioned.fill(
              child: ubicacion == null
                  ? _Ubicando(
                      sinUbicacion: _sinUbicacion,
                      alReintentar: _ubicar,
                      alViajarLibre: () => _iniciar(null),
                    )
                  : MapaDestino(
                      ubicacion: ubicacion,
                      destino: destino?.posicion,
                      trazado: ruta?.value?.trazado ?? const [],
                      controlador: _mapa,
                      alElegirDestino: (punto) =>
                          _elegir(Destino.enMapa(punto)),
                      relleno: EdgeInsets.only(
                        top: margen.top + Medidas.botonVolver + Espacios.m,
                        bottom: margen.bottom + _altoTarjeta,
                      ),
                    ),
            ),
            Positioned(
              top: margen.top + Espacios.s,
              left: Espacios.m,
              right: Espacios.m,
              child: Row(
                children: [
                  BotonMapa(
                    icono: Icons.arrow_back_rounded,
                    descripcion: 'Volver',
                    circular: true,
                    alPresionar: () => context.pop(),
                  ),
                  const SizedBox(width: Espacios.s),
                  Expanded(child: _BarraBusqueda(alPresionar: _buscar)),
                ],
              ),
            ),
            if (ubicacion != null)
              Positioned(
                left: Espacios.m,
                right: Espacios.m,
                bottom: margen.bottom + Espacios.m,
                child: _TarjetaCopiloto(
                  destino: destino,
                  ruta: ruta,
                  iniciando: _iniciando,
                  errorInicio: _errorInicio,
                  alQuitar: _quitarDestino,
                  alReintentar: () => ref.invalidate(
                    rutaPlaneadaProvider((ubicacion, destino!.posicion)),
                  ),
                  alIniciar: () => _iniciar(destino, ruta: ruta?.value),
                  alViajarLibre: () => _iniciar(null),
                  alVerPasos: (r) => mostrarPasosRuta(context, r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Buscar destino": abre la búsqueda por nombre (no es un campo).
class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({required this.alPresionar});

  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radios.pildora),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(shape: forma, shadows: colores.sombraTarjeta),
      child: Material(
        color: colores.superficie,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: alPresionar,
          child: SizedBox(
            height: Medidas.altoBarraBusqueda,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacios.m),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: Medidas.icono,
                    color: colores.textoSecundario,
                  ),
                  const SizedBox(width: Espacios.xs),
                  Expanded(
                    child: Text(
                      'Buscar destino',
                      style: context.tipografia.cuerpo.copyWith(
                        color: colores.textoSecundario,
                      ),
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

/// Mientras no hay ubicación: buscando, o el aviso si no se pudo obtener.
class _Ubicando extends StatelessWidget {
  const _Ubicando({
    required this.sinUbicacion,
    required this.alReintentar,
    required this.alViajarLibre,
  });

  final bool sinUbicacion;
  final VoidCallback alReintentar;
  final VoidCallback alViajarLibre;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espacios.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sinUbicacion)
              Icon(
                Icons.location_off_outlined,
                size: Medidas.iconoEstado,
                color: colores.textoTerciario,
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: Espacios.m),
            Text(
              sinUbicacion
                  ? 'No pudimos obtener tu ubicación'
                  : 'Buscando tu ubicación…',
              textAlign: TextAlign.center,
              style: tipografia.subtitulo.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
            if (sinUbicacion) ...[
              const SizedBox(height: Espacios.xxs),
              Text(
                'Prueba en un lugar con mejor señal.',
                textAlign: TextAlign.center,
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
              TextButton(
                onPressed: alReintentar,
                child: const Text('Reintentar'),
              ),
              TextButton(
                onPressed: alViajarLibre,
                child: const Text('Hacer un recorrido libre'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de abajo: sin destino, cómo elegirlo; con destino, su nombre, la
/// ruta (o su error) e "Iniciar con destino".
class _TarjetaCopiloto extends StatelessWidget {
  const _TarjetaCopiloto({
    required this.destino,
    required this.ruta,
    required this.iniciando,
    required this.errorInicio,
    required this.alQuitar,
    required this.alReintentar,
    required this.alIniciar,
    required this.alViajarLibre,
    required this.alVerPasos,
  });

  final Destino? destino;
  final AsyncValue<RutaPlaneada>? ruta;
  final bool iniciando;
  final String? errorInicio;
  final VoidCallback alQuitar;
  final VoidCallback alReintentar;
  final VoidCallback alIniciar;
  final VoidCallback alViajarLibre;
  final ValueChanged<RutaPlaneada> alVerPasos;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final destino = this.destino;

    final contenido = <Widget>[
      if (destino == null) ...[
        Text(
          '¿A dónde vas?',
          style: tipografia.subtitulo.copyWith(
            fontWeight: FontWeight.w700,
            color: colores.textoPrincipal,
          ),
        ),
        const SizedBox(height: Espacios.xxs),
        Text(
          'Toca o mantén pulsado el mapa, o busca un lugar por su nombre.',
          style: tipografia.cuerpoPequeno.copyWith(
            color: colores.textoSecundario,
          ),
        ),
      ] else ...[
        _FilaDestino(destino: destino, alQuitar: alQuitar),
        const SizedBox(height: Espacios.m),
        ...switch (ruta) {
          AsyncData(value: final ruta) => [
            _FilaResumen(ruta: ruta, alVerPasos: () => alVerPasos(ruta)),
            const SizedBox(height: Espacios.s),
            // Modo aprendizaje (HU-31): se elige antes de salir
            const InterruptorAprendizaje(),
            const SizedBox(height: Espacios.m),
            BotonPrimario(
              texto: 'Iniciar con destino',
              icono: Icons.play_arrow_rounded,
              cargando: iniciando,
              alPresionar: alIniciar,
            ),
          ],
          AsyncError(:final error) => [
            _AvisoRuta(
              error: error,
              iniciando: iniciando,
              alReintentar: alReintentar,
              alViajarLibre: alViajarLibre,
            ),
          ],
          _ => [const _Calculando()],
        },
      ],
      if (errorInicio != null) ...[
        const SizedBox(height: Espacios.s),
        AvisoError(mensaje: errorInicio!),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(Espacios.m),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjeta),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contenido,
      ),
    );
  }
}

class _FilaDestino extends StatelessWidget {
  const _FilaDestino({required this.destino, required this.alQuitar});

  final Destino destino;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Row(
      children: [
        Container(
          width: Medidas.cajaIconoFila,
          height: Medidas.cajaIconoFila,
          decoration: BoxDecoration(
            color: colores.encabezadoFondo,
            borderRadius: BorderRadius.circular(Radios.cajaIcono),
          ),
          child: Icon(
            Icons.flag_rounded,
            size: Medidas.icono,
            color: colores.encabezadoAcento,
          ),
        ),
        const SizedBox(width: Espacios.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destino.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tipografia.subtitulo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colores.textoPrincipal,
                ),
              ),
              Text(
                destino.direccion ?? FormatoRuta.coordenadas(destino.posicion),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tipografia.cuerpoPequeno.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quitar destino',
          onPressed: alQuitar,
          icon: Icon(Icons.close_rounded, color: colores.textoSecundario),
        ),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.ruta, required this.alVerPasos});

  final RutaPlaneada ruta;
  final VoidCallback alVerPasos;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final numero = tipografia.numeroMetrica.copyWith(
      fontWeight: FontWeight.w700,
      color: colores.textoPrincipal,
    );
    return Row(
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: Medidas.icono,
          color: colores.rutaPlaneada,
        ),
        const SizedBox(width: Espacios.xs),
        Expanded(child: Text(FormatoRuta.resumen(ruta), style: numero)),
        TextButton(
          onPressed: ruta.pasos.isEmpty ? null : alVerPasos,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ver pasos'),
              Icon(Icons.chevron_right_rounded, size: Medidas.icono),
            ],
          ),
        ),
      ],
    );
  }
}

class _Calculando extends StatelessWidget {
  const _Calculando();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Row(
      children: [
        SizedBox.square(
          dimension: Medidas.icono,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: colores.rutaPlaneada,
          ),
        ),
        const SizedBox(width: Espacios.s),
        Text(
          'Calculando la ruta…',
          style: context.tipografia.cuerpo.copyWith(
            color: colores.textoSecundario,
          ),
        ),
      ],
    );
  }
}

/// Sin ruta, sin conexión o sin servicio: qué pasó y las salidas.
class _AvisoRuta extends StatelessWidget {
  const _AvisoRuta({
    required this.error,
    required this.iniciando,
    required this.alReintentar,
    required this.alViajarLibre,
  });

  final Object error;
  final bool iniciando;
  final VoidCallback alReintentar;
  final VoidCallback alViajarLibre;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final error = this.error;
    final (titulo, mensaje, reintentable) = switch (error) {
      ErrorNavegacion(motivo: MotivoErrorNavegacion.sinRuta) => (
        error.titulo,
        '${error.mensaje}. Elige otro punto cerca de una calle.',
        false,
      ),
      ErrorNavegacion() => (error.titulo, error.mensaje, true),
      ErrorApi(:final mensaje) => (
        'No se pudo calcular la ruta',
        mensaje,
        true,
      ),
      _ => ('No se pudo calcular la ruta', ErrorApi.inesperado, true),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Espacios.s),
          decoration: BoxDecoration(
            color: colores.tinteAdvertencia,
            borderRadius: BorderRadius.circular(Radios.campo),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.wrong_location_outlined,
                size: Medidas.icono,
                color: colores.advertencia,
              ),
              const SizedBox(width: Espacios.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: tipografia.cuerpo.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colores.textoPrincipal,
                      ),
                    ),
                    Text(
                      mensaje,
                      style: tipografia.cuerpoPequeno.copyWith(
                        color: colores.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacios.s),
        Row(
          children: [
            if (reintentable) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: alReintentar,
                  child: const Text('Reintentar'),
                ),
              ),
              const SizedBox(width: Espacios.xs),
            ],
            Expanded(
              child: BotonPrimario(
                texto: 'Recorrido libre',
                cargando: iniciando,
                alPresionar: alViajarLibre,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
