import 'package:flutter/material.dart';

/// Maniobra que se marca a mano durante un viaje en modo calibración, para
/// ubicarla después en el CSV al ajustar el filtro y los detectores.
enum TipoMarca {
  frenadaFuerte(
    'frenada_fuerte',
    'Frenada fuerte',
    'Fren.',
    Icons.warning_amber_rounded,
  ),
  aceleracionFuerte(
    'aceleracion_fuerte',
    'Aceleración fuerte',
    'Acel.',
    Icons.fast_forward_rounded,
  ),
  giroBrusco('giro_brusco', 'Giro brusco', 'Giro', Icons.turn_right_rounded),
  bache('bache', 'Bache', 'Bache', Icons.terrain_outlined),
  telefonoMovido(
    'telefono_movido',
    'Teléfono movido',
    'Tel.',
    Icons.smartphone_outlined,
  );

  const TipoMarca(this.etiqueta, this.texto, this.abreviatura, this.icono);

  /// Valor de la columna `etiqueta` del CSV.
  final String etiqueta;

  /// Nombre en la hoja de opciones y en la confirmación.
  final String texto;

  /// Nombre corto en el panel de diagnóstico.
  final String abreviatura;
  final IconData icono;
}
