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

  // Trazo de los anillos pequeños (detalle del viaje)
  static const trazoAnilloPequeno = 10.0;

  // Anillo de DriveScore del resumen del viaje (docs/diseno.md, 7.1)
  static const anilloResumen = 150.0;
  static const trazoAnillo = 12.0;

  // DriveScore en el detalle del viaje y barras por categoría (docs/diseno.md, 7.1)
  static const anilloDetalle = 76.0;
  static const altoBarra = 8.0;

  // Inicio, diseño B (docs/diseno.md, 7.1)
  static const anilloEncabezadoInicio = 132.0;
  static const altoBotonInicio = 64.0;
  static const circuloBotonInicio = 46.0;
  // Línea bajo el nombre (cápsula o aviso): alto mínimo, para que no salte
  static const altoLineaEstadoInicio = 44.0;

  // Histórico del DriveScore (docs/diseno.md, 7.1)
  static const altoGrafico = 200.0;
  static const puntoGrafico = 8.0;
  static const puntoGraficoUltimo = 12.0;

  // Pantallas principales (docs/diseno.md, 7.1)
  static const avatar = 44.0;
  static const avatarGrande = 64.0;
  static const altoBloqueEnVivo = 460.0;
  static const circuloEstado = 64.0;
  static const circuloDescartado = 88.0;
  static const iconoEstado = 32.0;

  // Marcar maniobra, modo calibración (docs/diseno.md, 7.1)
  static const altoBotonMarca = 64.0;
  static const altoOpcionMarca = 96.0;

  // Avisos de eventos en vivo (docs/diseno.md, 7.1)
  static const altoCapsulaEvento = 52.0;

  // Historial de viajes (docs/diseno.md, 7.1)
  static const cajaIconoFila = 44.0;
  static const altoCabeceraDetalle = 280.0;
  static const superposicionDetalle = 40.0;
  static const ilustracionVacia = 160.0;
  static const puntoRecorrido = 12.0;

  // Mapa del viaje, HU-29 (docs/diseno.md, 7.1)
  static const altoMapaResumen = 180.0;
  static const altoMapaDetalle = 300.0;
  static const marcadorEvento = 28.0;
  static const marcadorEventoSeleccionado = 40.0;
  static const haloMarcador = 64.0;
  static const marcadorInicio = 20.0;
  static const altoChipMapa = 44.0;
  static const anchoBurbujaEvento = 240.0;
  static const altoBurbujaEvento = 72.0;
  static const cajaIconoContador = 40.0;
  static const altoEncabezadoResumen = 176.0;
  static const superposicionMapaResumen = 64.0;
  static const circuloCheckResumen = 56.0;

  // Pantallas de autenticación (docs/diseno.md, 4.2)
  static const superposicionTarjeta = 56.0;
  static const altoEncabezadoLogin = 392.0;
  static const altoMinimoEncabezadoRegistro = 240.0;
}
