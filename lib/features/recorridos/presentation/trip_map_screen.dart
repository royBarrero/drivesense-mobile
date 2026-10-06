import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../telemetria/models/event_detector.dart';
import '../../telemetria/models/route.dart';
import 'trip_format.dart';
import 'widgets/live_alert_capsules.dart';
import 'widgets/map_button.dart';
import 'widgets/trip_map.dart';

/// Lo que muestra el mapa completo. Lo arman el resumen (datos del teléfono) y
/// el detalle (datos del backend, que solo entrega viajes propios).
class DatosMapaViaje {
  const DatosMapaViaje({
    required this.ruta,
    required this.eventos,
    required this.llegada,
    required this.duracionS,
    required this.distanciaM,
  });

  /// Al menos dos puntos.
  final List<PuntoRuta> ruta;

  /// En orden cronológico.
  final List<EventoRiesgo> eventos;
  final DateTime llegada;
  final int duracionS;
  final double distanciaM;

  /// Hay ruta que dibujar.
  static bool hayRuta(List<PuntoRuta>? ruta) => (ruta?.length ?? 0) >= 2;
}

/// Mapa completo del viaje (HU-29): la ruta con los eventos, filtros por tipo
/// y la lista de eventos abajo; tocar uno lo centra y muestra su detalle.
class MapaViajePantalla extends StatefulWidget {
  const MapaViajePantalla({super.key, required this.datos});

  final DatosMapaViaje datos;

  @override
  State<MapaViajePantalla> createState() => _MapaViajePantallaState();
}

class _MapaViajePantallaState extends State<MapaViajePantalla> {
  static const _hojaInicial = 0.4;
  static const _hojaMinima = 0.2;
  static const _hojaMaxima = 0.75;

  final _controlador = ControladorMapaViaje();

  /// Tipo filtrado; nulo = todos.
  TipoEvento? _filtro;
  EventoRiesgo? _seleccionado;
  double _hoja = _hojaInicial;

  List<EventoRiesgo> get _visibles => [
    for (final evento in widget.datos.eventos)
      if (_filtro == null || evento.tipo == _filtro) evento,
  ];

  void _filtrar(TipoEvento? tipo) => setState(() {
    _filtro = tipo;
    if (tipo != null && _seleccionado?.tipo != tipo) _seleccionado = null;
  });

  void _seleccionar(EventoRiesgo evento) =>
      setState(() => _seleccionado = evento);

  void _verRutaCompleta() {
    setState(() => _seleccionado = null);
    _controlador.verRutaCompleta();
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final datos = widget.datos;
    final margenSuperior = MediaQuery.paddingOf(context).top;
    final hayEventos = datos.eventos.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.fondo,
        body: LayoutBuilder(
          builder: (context, limites) {
            final altoHoja = limites.maxHeight * _hoja;
            final altoControles =
                margenSuperior +
                Espacios.s +
                Medidas.botonVolver +
                (hayEventos ? Espacios.s + Medidas.altoChipMapa : 0) +
                Espacios.s;
            return Stack(
              children: [
                Positioned.fill(
                  child: MapaViaje(
                    ruta: datos.ruta,
                    eventos: _visibles,
                    seleccionado: _seleccionado,
                    alTocarEvento: _seleccionar,
                    interactivo: true,
                    controlador: _controlador,
                    relleno: EdgeInsets.only(
                      top: altoControles,
                      bottom: altoHoja,
                    ),
                    alineacionAtribucion: Alignment.bottomCenter,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: margenSuperior + Espacios.s,
                  child: _Controles(
                    datos: datos,
                    filtro: _filtro,
                    alFiltrar: _filtrar,
                  ),
                ),
                Positioned(
                  right: Espacios.m,
                  bottom: altoHoja + Espacios.m,
                  child: BotonMapa(
                    icono: Icons.center_focus_weak_rounded,
                    descripcion: 'Ver la ruta entera',
                    alPresionar: _verRutaCompleta,
                  ),
                ),
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: (aviso) {
                    setState(() => _hoja = aviso.extent);
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    initialChildSize: _hojaInicial,
                    minChildSize: _hojaMinima,
                    maxChildSize: _hojaMaxima,
                    builder: (context, desplazamiento) => _HojaEventos(
                      eventos: _visibles,
                      hayEventos: hayEventos,
                      seleccionado: _seleccionado,
                      alSeleccionar: _seleccionar,
                      desplazamiento: desplazamiento,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Volver, título del viaje y, si hubo eventos, los filtros por tipo.
class _Controles extends StatelessWidget {
  const _Controles({
    required this.datos,
    required this.filtro,
    required this.alFiltrar,
  });

  final DatosMapaViaje datos;
  final TipoEvento? filtro;
  final ValueChanged<TipoEvento?> alFiltrar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final eventos = datos.eventos;
    final tipos = [
      for (final tipo in TipoEvento.values)
        if (eventos.any((e) => e.tipo == tipo)) tipo,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacios.m),
          child: Row(
            children: [
              BotonMapa(
                icono: Icons.chevron_left_rounded,
                descripcion: 'Volver',
                circular: true,
                alPresionar: () => context.pop(),
              ),
              const SizedBox(width: Espacios.xs),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espacios.m,
                    vertical: Espacios.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colores.superficie,
                    borderRadius: BorderRadius.circular(Radios.micro),
                    boxShadow: colores.sombraTarjeta,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ruta del viaje',
                        style: tipografia.subtitulo.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                      Text(
                        '${FormatoViaje.franjaHoraria(datos.llegada, datos.duracionS)}'
                        ' · ${FormatoViaje.kilometros(datos.distanciaM)} km',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tipografia.cuerpoPequeno.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (eventos.isNotEmpty) ...[
          const SizedBox(height: Espacios.s),
          SizedBox(
            height: Medidas.altoChipMapa,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Espacios.m),
              children: [
                _ChipFiltro(
                  texto: 'Todos',
                  cantidad: eventos.length,
                  activo: filtro == null,
                  alPresionar: () => alFiltrar(null),
                ),
                for (final tipo in tipos) ...[
                  const SizedBox(width: Espacios.xs),
                  _ChipFiltro(
                    tipo: tipo,
                    texto: EstiloEvento.de(tipo, colores).plural,
                    cantidad: eventos.where((e) => e.tipo == tipo).length,
                    activo: filtro == tipo,
                    alPresionar: () => alFiltrar(tipo),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Filtro de la lista y del mapa: "Todos 5" o el tipo con su ícono y cantidad.
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    this.tipo,
    required this.texto,
    required this.cantidad,
    required this.activo,
    required this.alPresionar,
  });

  final TipoEvento? tipo;
  final String texto;
  final int cantidad;
  final bool activo;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final tipo = this.tipo;
    final colorTexto = activo ? colores.sobrePrimario : colores.textoPrincipal;
    return Material(
      color: activo ? colores.textoPrincipal : colores.superficie,
      shape: StadiumBorder(
        side: BorderSide(
          color: activo ? colores.textoPrincipal : colores.borde,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: alPresionar,
        child: Padding(
          padding: EdgeInsets.only(
            left: tipo == null ? Espacios.m : Espacios.xxs * 1.5,
            right: Espacios.m,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tipo != null) ...[
                Builder(
                  builder: (context) {
                    final estilo = EstiloEvento.de(tipo, colores);
                    return Container(
                      width: Medidas.altoChipMapa - Espacios.s,
                      height: Medidas.altoChipMapa - Espacios.s,
                      decoration: BoxDecoration(
                        color: estilo.tinte,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        estilo.icono,
                        size: Medidas.iconoPequeno,
                        color: estilo.texto,
                      ),
                    );
                  },
                ),
                const SizedBox(width: Espacios.xs),
              ],
              Text(
                texto,
                style: tipografia.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorTexto,
                ),
              ),
              const SizedBox(width: Espacios.xs),
              Text(
                '$cantidad',
                style: tipografia.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorTexto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con la lista de eventos (filtrada).
class _HojaEventos extends StatelessWidget {
  const _HojaEventos({
    required this.eventos,
    required this.hayEventos,
    required this.seleccionado,
    required this.alSeleccionar,
    required this.desplazamiento,
  });

  final List<EventoRiesgo> eventos;
  final bool hayEventos;
  final EventoRiesgo? seleccionado;
  final ValueChanged<EventoRiesgo> alSeleccionar;
  final ScrollController desplazamiento;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return Container(
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radios.tarjeta),
        ),
        boxShadow: colores.sombraTarjeta,
      ),
      child: ListView(
        controller: desplazamiento,
        padding: EdgeInsets.fromLTRB(
          Espacios.m,
          Espacios.s,
          Espacios.m,
          MediaQuery.paddingOf(context).bottom + Espacios.m,
        ),
        children: [
          Center(
            child: Container(
              width: Espacios.xxl + Espacios.xs,
              height: Espacios.xxs,
              decoration: BoxDecoration(
                color: colores.bordeFuerte,
                borderRadius: BorderRadius.circular(Radios.pildora),
              ),
            ),
          ),
          const SizedBox(height: Espacios.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacios.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'Eventos del viaje',
                    style: tipografia.subtituloGrande.copyWith(
                      color: colores.textoPrincipal,
                    ),
                  ),
                ),
                if (hayEventos)
                  Text(
                    'Toca uno para verlo',
                    style: tipografia.cuerpoPequeno.copyWith(
                      color: colores.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espacios.s),
          if (!hayEventos)
            Padding(
              padding: const EdgeInsets.all(Espacios.xs),
              child: Text(
                'Sin eventos de riesgo en este viaje. ¡Sigue así!',
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ),
          for (final evento in eventos)
            _FilaEvento(
              evento: evento,
              seleccionado: evento == seleccionado,
              alPresionar: () => alSeleccionar(evento),
            ),
        ],
      ),
    );
  }
}

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({
    required this.evento,
    required this.seleccionado,
    required this.alPresionar,
  });

  final EventoRiesgo evento;
  final bool seleccionado;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final estilo = EstiloEvento.de(evento.tipo, colores);
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radios.micro),
      side: seleccionado ? BorderSide(color: colores.borde) : BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacios.xxs),
      child: Material(
        color: seleccionado ? colores.superficieAlt : colores.superficie,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(Espacios.xs),
            child: Row(
              children: [
                Container(
                  width: Medidas.cajaIconoFila,
                  height: Medidas.cajaIconoFila,
                  decoration: BoxDecoration(
                    color: estilo.tinte,
                    borderRadius: BorderRadius.circular(Radios.cajaIcono),
                  ),
                  child: Icon(
                    estilo.icono,
                    size: Medidas.icono,
                    color: estilo.texto,
                  ),
                ),
                const SizedBox(width: Espacios.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estilo.nombre,
                        style: tipografia.subtitulo.copyWith(
                          color: colores.textoPrincipal,
                        ),
                      ),
                      Text(
                        FormatoEvento.detalle(evento),
                        style: tipografia.cuerpo.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Espacios.xs),
                Text(
                  FormatoViaje.hora(evento.fecha),
                  style: tipografia.numeroMetrica.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colores.textoPrincipal,
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
