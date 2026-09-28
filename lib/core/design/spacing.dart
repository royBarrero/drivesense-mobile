/// Espaciado y radios (docs/diseno.md, secciones 3.1 y 3.2). No cambian entre modos.
abstract final class Espacios {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const s = 12.0;
  static const m = 16.0;
  static const l = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radios {
  static const pildora = 999.0;
  static const tarjeta = 24.0;
  static const micro = 16.0;
  static const cajaIcono = 12.0;
  static const campo = 16.0;
  static const encabezado = 32.0;
  static const tarjetaDestacada = 28.0;
  static const logo = 14.0;
}

/// Medidas fijas de componentes.
abstract final class Medidas {
  static const altoCampo = 52.0;
  static const altoBotonFormulario = 54.0;
  static const icono = 20.0;
  static const iconoPequeno = 16.0;
  static const iconoNavegacion = 24.0;
  static const logo = 44.0;
  static const botonVolver = 44.0;
  static const cajaIcono = 36.0;

  // Anillo de DriveScore de Inicio (docs/diseno.md, 7)
  static const anilloInicio = 88.0;
  static const trazoAnilloPequeno = 10.0;

  // Pantallas principales (docs/diseno.md, 7.1)
  static const avatar = 44.0;
  static const avatarGrande = 64.0;
  static const altoBloqueEnVivo = 460.0;
  static const altoBloqueResumen = 300.0;
  static const superposicionResumen = 48.0;
  static const circuloEstado = 64.0;
  static const circuloDescartado = 88.0;
  static const iconoEstado = 32.0;

  // Pantallas de autenticación (docs/diseno.md, 4.2)
  static const superposicionTarjeta = 56.0;
  static const altoEncabezadoLogin = 392.0;
  static const altoMinimoEncabezadoRegistro = 240.0;
}
