import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../telemetria/models/event_detector.dart';
import '../trip_format.dart';

/// Colores, ícono y textos de cada tipo de evento (HU-14, docs/diseno.md 1.1).
class EstiloEvento {
  const EstiloEvento._({
    required this.vivo,
    required this.texto,
    required this.tinte,
    required this.icono,
    required this.nombre,
    required this.contador,
    required this.plural,
  });

  factory EstiloEvento.de(TipoEvento tipo, ColoresDriveSense colores) =>
      switch (tipo) {
        TipoEvento.frenadaBrusca => EstiloEvento._(
          vivo: colores.eventoFrenada,
          texto: colores.textoEventoFrenada,
          tinte: colores.tinteEventoFrenada,
          icono: Icons.south,
          nombre: 'Frenada brusca',
          contador: 'Frenadas',
          plural: 'Frenadas',
        ),
        TipoEvento.aceleracionSevera => EstiloEvento._(
          vivo: colores.eventoAceleracion,
          texto: colores.textoEventoAceleracion,
          tinte: colores.tinteEventoAceleracion,
          icono: Icons.fast_forward_outlined,
          nombre: 'Aceleración severa',
          contador: 'Acelerac.',
          plural: 'Aceleraciones',
        ),
        TipoEvento.giroAgresivo => EstiloEvento._(
          vivo: colores.eventoGiro,
          texto: colores.textoEventoGiro,
          tinte: colores.tinteEventoGiro,
          icono: Icons.turn_right,
          nombre: 'Giro agresivo',
          contador: 'Giros',
          plural: 'Giros',
        ),
        TipoEvento.excesoVelocidad => EstiloEvento._(
          vivo: colores.eventoVelocidad,
          texto: colores.textoEventoVelocidad,
          tinte: colores.tinteEventoVelocidad,
          icono: Icons.speed,
          nombre: 'Exceso de velocidad',
          contador: 'Velocidad',
          plural: 'Excesos',
        ),
      };

  /// Sobre el encabezado oscuro (aro, punto, cápsula, número).
  final Color vivo;

  /// Sobre fondos claros (tarjeta de contadores).
  final Color texto;
  final Color tinte;
  final IconData icono;

  /// En la cápsula del aviso.
  final String nombre;

  /// En la tarjeta de contadores de la pantalla en vivo.
  final String contador;

  /// Nombre completo en plural: contadores y filtros del mapa (HU-29).
  final String plural;

  /// Halo del marcador elegido en el mapa (HU-29): el tono vivo, translúcido.
  Color get halo => vivo.withValues(alpha: 0.3);
}

/// Aviso de un evento puntual (diseño B): cápsula grande en el color del
/// evento, en lugar de la máxima.
class CapsulaEvento extends StatelessWidget {
  const CapsulaEvento({super.key, required this.tipo});

  final TipoEvento tipo;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = EstiloEvento.de(tipo, colores);
    return Container(
      height: Medidas.altoCapsulaEvento,
      padding: const EdgeInsets.symmetric(horizontal: Espacios.xl),
      decoration: BoxDecoration(
        color: estilo.vivo,
        borderRadius: BorderRadius.circular(Radios.pildora),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            estilo.icono,
            size: Medidas.iconoNavegacion,
            color: colores.sobreAcentoOscuro,
          ),
          const SizedBox(width: Espacios.s),
          Text(
            estilo.nombre,
            style: context.tipografia.subtituloGrande.copyWith(
              color: colores.sobreAcentoOscuro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de exceso de velocidad (diseño C): cuánto lleva sobre el límite.
class CapsulaExceso extends StatelessWidget {
  const CapsulaExceso({super.key, required this.duracionS});

  final double duracionS;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final color = colores.eventoVelocidad;
    final limite = UmbralesDeteccion.limiteVelocidadKmh.round();
    return Container(
      height: Medidas.altoCapsulaEvento,
      padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
      decoration: BoxDecoration(
        color: colores.encabezadoSuperficie,
        borderRadius: BorderRadius.circular(Radios.pildora),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: Medidas.icono, color: color),
          const SizedBox(width: Espacios.xs),
          Text(
            'Sobre el límite de $limite',
            style: tipografia.subtitulo.copyWith(
              color: colores.encabezadoTexto,
            ),
          ),
          const SizedBox(width: Espacios.s),
          Text(
            FormatoViaje.minutosSegundos(duracionS.floor()),
            style: tipografia.numeroMetrica.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
