import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/design.dart';
import '../../../telemetria/models/event_detector.dart';
import '../../../telemetria/models/route.dart';
import '../../models/route_simplifier.dart';
import '../trip_format.dart';
import 'live_alert_capsules.dart';

/// Proveedor de mosaicos del mapa del viaje (HU-29): OpenStreetMap. Es lo
/// único que conoce al proveedor; las pantallas solo usan [MapaViaje].
abstract final class _Proveedor {
  static const urlMosaicos = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// La política de uso de OSM pide identificar la app en el User-Agent.
  static const paqueteApp = 'com.drivesense.drivesense';
  static const atribucion = '© OpenStreetMap';
  static final urlAtribucion = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
  static const zoomMaximo = 18.0;
  static const zoomMinimo = 3.0;
}

/// Zoom al encuadrar la ruta (como máximo) y al elegir un evento (como mínimo).
const _zoomRuta = 17.0;
const _zoomEvento = 16.0;
const _duracionAnimacion = Duration(milliseconds: 450);

/// Acciones sobre el mapa desde la pantalla, sin depender del proveedor.
class ControladorMapaViaje {
  _MapaViajeState? _estado;

  /// Vuelve a encuadrar toda la ruta.
  void verRutaCompleta() => _estado?._encuadrarRuta(animado: true);
}

/// Mapa del viaje (HU-29): la ruta simplificada con su inicio y su fin y los
/// eventos de riesgo. Recibe solo datos de la app (ruta y eventos), así que
/// cambiar de proveedor de mapas no toca las pantallas.
///
/// Sin internet (fallan los mosaicos sin que haya cargado ninguno), muestra un
/// aviso en lugar del mapa y lo informa con [alCambiarDisponibilidad].
class MapaViaje extends StatefulWidget {
  const MapaViaje({
    super.key,
    required this.ruta,
    required this.eventos,
    this.seleccionado,
    this.alTocarEvento,
    this.alTocar,
    this.interactivo = false,
    this.relleno = EdgeInsets.zero,
    this.controlador,
    this.alCambiarDisponibilidad,
    this.alineacionAtribucion = Alignment.bottomRight,
  });

  /// Al menos dos puntos.
  final List<PuntoRuta> ruta;

  /// Eventos a marcar (la pantalla ya aplicó sus filtros).
  final List<EventoRiesgo> eventos;

  /// Evento destacado, con su detalle encima; al cambiar, el mapa lo centra.
  final EventoRiesgo? seleccionado;

  final ValueChanged<EventoRiesgo>? alTocarEvento;

  /// Toque en un mapa no [interactivo] (p. ej. para abrir el mapa completo).
  final VoidCallback? alTocar;

  /// Se puede mover y acercar; si no, el mapa queda fijo y no captura gestos
  /// (va dentro de una lista).
  final bool interactivo;

  /// Zona que tapan los controles de la pantalla: la ruta y el evento se
  /// encuadran en el resto.
  final EdgeInsets relleno;

  final ControladorMapaViaje? controlador;

  /// `false` al mostrar el aviso sin conexión, `true` al volver a cargar.
  final ValueChanged<bool>? alCambiarDisponibilidad;

  /// Dónde va la atribución, dentro de [relleno].
  final Alignment alineacionAtribucion;

  @override
  State<MapaViaje> createState() => _MapaViajeState();
}

class _MapaViajeState extends State<MapaViaje>
    with SingleTickerProviderStateMixin {
  final _mapa = MapController();
  late final AnimationController _animacion;
  MapCamera? _desde;
  LatLng _centroDestino = const LatLng(0, 0);
  double _zoomDestino = 0;
  late List<LatLng> _ruta;
  bool _listo = false;

  /// Algún mosaico cargó: un error posterior no es falta de conexión.
  bool _mosaicoCargado = false;
  bool _sinConexion = false;

  /// Cambia al reintentar, para volver a crear el mapa.
  int _intento = 0;

  @override
  void initState() {
    super.initState();
    widget.controlador?._estado = this;
    _ruta = _simplificar(widget.ruta);
    _animacion = AnimationController(vsync: this, duration: _duracionAnimacion)
      ..addListener(_animar);
  }

  @override
  void didUpdateWidget(MapaViaje anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.controlador != widget.controlador) {
      anterior.controlador?._estado = null;
      widget.controlador?._estado = this;
    }
    if (!identical(anterior.ruta, widget.ruta)) {
      _ruta = _simplificar(widget.ruta);
    }
    final seleccionado = widget.seleccionado;
    if (seleccionado != null && seleccionado != anterior.seleccionado) {
      _centrarEn(seleccionado);
    }
  }

  @override
  void dispose() {
    if (widget.controlador?._estado == this) widget.controlador?._estado = null;
    _animacion.dispose();
    _mapa.dispose();
    super.dispose();
  }

  static List<LatLng> _simplificar(List<PuntoRuta> ruta) => [
    for (final punto in simplificarRuta(ruta))
      LatLng(punto.latitud, punto.longitud),
  ];

  static LatLng _posicion(EventoRiesgo evento) =>
      LatLng(evento.latitud, evento.longitud);

  /// Relleno del encuadre: lo que tapa la pantalla más un margen.
  EdgeInsets get _margen => widget.relleno + const EdgeInsets.all(Espacios.xl);

  /// Puntos que deben quedar a la vista al ver la ruta entera.
  List<LatLng> get _puntosRuta => [
    ..._ruta,
    for (final evento in widget.eventos) _posicion(evento),
  ];

  CameraFit get _encuadreRuta => CameraFit.coordinates(
    coordinates: _puntosRuta,
    padding: _margen,
    maxZoom: _zoomRuta,
  );

  void _encuadrarRuta({required bool animado}) {
    if (!_listo) return;
    final camara = _mapa.camera;
    final limites = LatLngBounds.fromPoints(_puntosRuta);
    // Todos los puntos en el mismo lugar: CameraFit no puede calcular el zoom
    final destino =
        limites.north == limites.south && limites.east == limites.west
        ? _camaraCentradaEn(limites.center, _zoomRuta)
        : _encuadreRuta.fit(camara);
    _moverA(destino.center, destino.zoom, animado: animado);
  }

  /// Centra [evento] en la zona visible, con su detalle encima.
  void _centrarEn(EventoRiesgo evento) {
    if (!_listo) return;
    final zoom = math.max(_mapa.camera.zoom, _zoomEvento);
    final destino = _camaraCentradaEn(
      _posicion(evento),
      zoom,
      // El detalle va encima del marcador: también tiene que verse
      arriba: Medidas.altoBurbujaEvento,
    );
    _moverA(destino.center, destino.zoom, animado: true);
  }

  /// Cámara con [punto] en el centro de la zona que no tapa [relleno] (más
  /// [arriba] dp reservados sobre él).
  MapCamera _camaraCentradaEn(LatLng punto, double zoom, {double arriba = 0}) {
    final camara = _mapa.camera;
    final relleno = widget.relleno + EdgeInsets.only(top: arriba);
    final desplazamiento =
        Offset(relleno.right - relleno.left, relleno.bottom - relleno.top) / 2;
    final proyectado = camara.projectAtZoom(punto, zoom) + desplazamiento;
    return camara.withPosition(
      center: camara.unprojectAtZoom(proyectado, zoom),
      zoom: zoom,
    );
  }

  void _moverA(LatLng centro, double zoom, {required bool animado}) {
    _animacion.stop();
    if (!animado) {
      _mapa.move(centro, zoom);
      return;
    }
    _desde = _mapa.camera;
    _centroDestino = centro;
    _zoomDestino = zoom;
    _animacion.forward(from: 0);
  }

  /// Cada cuadro de la animación de [_moverA].
  void _animar() {
    final desde = _desde;
    if (desde == null) return;
    final t = Curves.easeInOutCubic.transform(_animacion.value);
    _mapa.move(
      LatLng(
        lerpDouble(desde.center.latitude, _centroDestino.latitude, t)!,
        lerpDouble(desde.center.longitude, _centroDestino.longitude, t)!,
      ),
      lerpDouble(desde.zoom, _zoomDestino, t)!,
    );
  }

  void _alFallarMosaico() {
    if (_mosaicoCargado || _sinConexion || !mounted) return;
    setState(() => _sinConexion = true);
    widget.alCambiarDisponibilidad?.call(false);
  }

  void _reintentar() {
    setState(() {
      _sinConexion = false;
      _mosaicoCargado = false;
      _listo = false;
      _intento++;
    });
    widget.alCambiarDisponibilidad?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    if (_sinConexion) {
      return _AvisoSinConexion(
        relleno: widget.relleno,
        alReintentar: _reintentar,
      );
    }

    final mapa = FlutterMap(
      key: ValueKey(_intento),
      mapController: _mapa,
      options: MapOptions(
        initialCameraFit: _encuadreRuta,
        minZoom: _Proveedor.zoomMinimo,
        maxZoom: _Proveedor.zoomMaximo,
        backgroundColor: colores.superficieAlt,
        interactionOptions: InteractionOptions(
          flags: widget.interactivo
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onMapReady: () {
          _listo = true;
          final seleccionado = widget.seleccionado;
          if (seleccionado != null) _centrarEn(seleccionado);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _Proveedor.urlMosaicos,
          userAgentPackageName: _Proveedor.paqueteApp,
          tileBuilder: (context, mosaico, imagen) {
            if (imagen.loadFinishedAt != null && !imagen.loadError) {
              _mosaicoCargado = true;
            }
            return mosaico;
          },
          errorTileCallback: (imagen, error, traza) => WidgetsBinding.instance
              .addPostFrameCallback((_) => _alFallarMosaico()),
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _ruta,
              strokeWidth: 5,
              gradientColors: colores.gradienteScore.colors,
              borderStrokeWidth: 3,
              borderColor: colores.bordeRuta,
            ),
          ],
        ),
        MarkerLayer(markers: _marcadores(colores)),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: widget.interactivo
              ? mapa
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.alTocar,
                  child: IgnorePointer(child: mapa),
                ),
        ),
        Positioned.fill(
          child: Padding(
            padding: widget.relleno + const EdgeInsets.all(Espacios.xs),
            child: Align(
              alignment: widget.alineacionAtribucion,
              child: const _Atribucion(),
            ),
          ),
        ),
      ],
    );
  }

  List<Marker> _marcadores(ColoresDriveSense colores) {
    final seleccionado = widget.seleccionado;
    return [
      Marker(
        point: _ruta.first,
        width: Medidas.marcadorInicio,
        height: Medidas.marcadorInicio,
        child: _MarcadorInicio(color: colores.primario),
      ),
      Marker(
        point: _ruta.last,
        width: Medidas.marcadorEvento,
        height: Medidas.marcadorEvento,
        child: const _MarcadorFin(),
      ),
      for (final evento in widget.eventos)
        if (evento != seleccionado)
          Marker(
            point: _posicion(evento),
            width: Medidas.marcadorEvento,
            height: Medidas.marcadorEvento,
            child: GestureDetector(
              onTap: widget.alTocarEvento == null
                  ? null
                  : () => widget.alTocarEvento!(evento),
              child: _MarcadorEvento(tipo: evento.tipo),
            ),
          ),
      if (seleccionado != null) ...[
        Marker(
          point: _posicion(seleccionado),
          width: Medidas.haloMarcador,
          height: Medidas.haloMarcador,
          child: _MarcadorEvento(tipo: seleccionado.tipo, seleccionado: true),
        ),
        // Encima del marcador, apoyada en él
        Marker(
          point: _posicion(seleccionado),
          width: Medidas.anchoBurbujaEvento,
          height:
              Medidas.altoBurbujaEvento +
              Medidas.marcadorEventoSeleccionado / 2 +
              Espacios.xs,
          alignment: Alignment.topCenter,
          child: Align(
            alignment: Alignment.topCenter,
            child: BurbujaEvento(evento: seleccionado),
          ),
        ),
      ],
    ];
  }
}

/// Detalle del evento elegido, sobre su marcador: tipo, hora y lo medido.
class BurbujaEvento extends StatelessWidget {
  const BurbujaEvento({super.key, required this.evento});

  final EventoRiesgo evento;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estilo = EstiloEvento.de(evento.tipo, colores);
    return Container(
      width: Medidas.anchoBurbujaEvento,
      height: Medidas.altoBurbujaEvento,
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.m,
        vertical: Espacios.s,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.micro),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estilo.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tipografia.subtitulo.copyWith(color: estilo.texto),
                ),
              ),
              Text(
                FormatoViaje.hora(evento.fecha),
                style: tipografia.cuerpoPequeno.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ),
          Text(
            FormatoEvento.detalle(evento),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tipografia.cuerpo.copyWith(color: colores.textoPrincipal),
          ),
        ],
      ),
    );
  }
}

class _MarcadorInicio extends StatelessWidget {
  const _MarcadorInicio({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colores.superficie,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: context.colores.sombraTarjeta,
      ),
    );
  }
}

class _MarcadorFin extends StatelessWidget {
  const _MarcadorFin();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: colores.encabezadoFondo,
        shape: BoxShape.circle,
        border: Border.all(color: colores.superficie, width: 2),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Icon(
        Icons.flag_rounded,
        size: Medidas.iconoPequeno,
        color: colores.encabezadoAcento,
      ),
    );
  }
}

/// Círculo en el color del tipo con su ícono; el elegido, más grande y con
/// un halo.
class _MarcadorEvento extends StatelessWidget {
  const _MarcadorEvento({required this.tipo, this.seleccionado = false});

  final TipoEvento tipo;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = EstiloEvento.de(tipo, colores);
    final tamano = seleccionado
        ? Medidas.marcadorEventoSeleccionado
        : Medidas.marcadorEvento;
    final marcador = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: estilo.texto,
        shape: BoxShape.circle,
        border: Border.all(color: colores.superficie, width: 2),
        boxShadow: colores.sombraTarjeta,
      ),
      child: Icon(
        estilo.icono,
        size: seleccionado ? Medidas.icono : Medidas.iconoPequeno,
        color: colores.superficie,
      ),
    );
    if (!seleccionado) return marcador;
    return Container(
      decoration: BoxDecoration(color: estilo.halo, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: marcador,
    );
  }
}

/// "© OpenStreetMap", siempre visible; abre la página de derechos.
class _Atribucion extends StatelessWidget {
  const _Atribucion();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.fondoAtribucion,
      borderRadius: BorderRadius.circular(Radios.pildora),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.pildora),
        onTap: () => launchUrl(
          _Proveedor.urlAtribucion,
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacios.xs,
            vertical: Espacios.xxs / 2,
          ),
          child: Text(
            _Proveedor.atribucion,
            style: context.tipografia.ayuda.copyWith(
              color: colores.textoSecundario,
            ),
          ),
        ),
      ),
    );
  }
}

/// En lugar del mapa cuando no cargan los mosaicos (sin internet).
class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion({required this.relleno, required this.alReintentar});

  final EdgeInsets relleno;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return ColoredBox(
      color: colores.superficieAlt,
      child: Padding(
        padding: relleno + const EdgeInsets.all(Espacios.s),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: Medidas.iconoEstado,
                  color: colores.textoTerciario,
                ),
                const SizedBox(height: Espacios.xs),
                Text(
                  'Sin conexión',
                  style: tipografia.subtitulo.copyWith(
                    color: colores.textoPrincipal,
                  ),
                ),
                Text(
                  'El mapa se verá cuando vuelvas a tener internet.',
                  textAlign: TextAlign.center,
                  style: tipografia.cuerpoPequeno.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
                TextButton(
                  onPressed: alReintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
