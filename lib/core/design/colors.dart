import 'package:flutter/material.dart';

/// Colores, degradados y sombras que dependen del modo (claro/oscuro).
///
/// Valores y uso de cada token: docs/diseno.md, secciones 1 y 3.3.
@immutable
class ColoresDriveSense extends ThemeExtension<ColoresDriveSense> {
  const ColoresDriveSense({
    required this.fondo,
    required this.superficie,
    required this.superficieAlt,
    required this.borde,
    required this.bordeFuerte,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.textoTerciario,
    required this.sobrePrimario,
    required this.primario,
    required this.primarioOscuro,
    required this.secundario,
    required this.confort,
    required this.peligro,
    required this.advertencia,
    required this.botonPrimario,
    required this.botonPrimarioPresionado,
    required this.enlace,
    required this.fondoBotonSecundario,
    required this.carril,
    required this.barraNavegacion,
    required this.bordePeligroSuave,
    required this.textoPeligro,
    required this.textoExito,
    required this.tintePrimario,
    required this.tinteConfort,
    required this.tintePeligro,
    required this.tinteAdvertencia,
    required this.tinteNavActivo,
    required this.tinteSecundario,
    required this.encabezadoFondo,
    required this.encabezadoSuperficie,
    required this.encabezadoBorde,
    required this.encabezadoAcento,
    required this.encabezadoTexto,
    required this.encabezadoTextoSecundario,
    required this.acentoOscuroTenue,
    required this.sobreAcentoOscuro,
    required this.eventoFrenada,
    required this.eventoAceleracion,
    required this.eventoGiro,
    required this.eventoVelocidad,
    required this.textoEventoFrenada,
    required this.textoEventoAceleracion,
    required this.textoEventoGiro,
    required this.textoEventoVelocidad,
    required this.tinteEventoFrenada,
    required this.tinteEventoAceleracion,
    required this.tinteEventoGiro,
    required this.tinteEventoVelocidad,
    required this.gradienteScore,
    required this.gradienteRellenoGrafica,
    required this.textoSobreGradiente,
    required this.superficieSobreGradiente,
    required this.lineasSobreGradiente,
    required this.bordeRuta,
    required this.fondoAtribucion,
    required this.sombraTarjeta,
    required this.sombraBotonPrimario,
    required this.sombraBotonAcento,
    required this.resplandorPunto,
  });

  final Color fondo;
  final Color superficie;
  final Color superficieAlt;
  final Color borde;
  final Color bordeFuerte;
  final Color textoPrincipal;
  final Color textoSecundario;
  final Color textoTerciario;
  final Color sobrePrimario;
  final Color primario;
  final Color primarioOscuro;
  final Color secundario;
  final Color confort;
  final Color peligro;
  final Color advertencia;
  final Color botonPrimario;
  final Color botonPrimarioPresionado;
  final Color enlace;
  final Color fondoBotonSecundario;
  final Color carril;
  final Color barraNavegacion;
  final Color bordePeligroSuave;
  final Color textoPeligro;
  final Color textoExito;

  final Color tintePrimario;
  final Color tinteConfort;
  final Color tintePeligro;
  final Color tinteAdvertencia;
  final Color tinteNavActivo;
  final Color tinteSecundario;

  final Color encabezadoFondo;
  final Color encabezadoSuperficie;
  final Color encabezadoBorde;
  final Color encabezadoAcento;
  final Color encabezadoTexto;
  final Color encabezadoTextoSecundario;
  final Color acentoOscuroTenue;
  final Color sobreAcentoOscuro;

  /// Eventos de riesgo (HU-14): tono vivo sobre el encabezado oscuro, texto
  /// sobre fondos claros y tinte de la tarjeta de contadores.
  final Color eventoFrenada;
  final Color eventoAceleracion;
  final Color eventoGiro;
  final Color eventoVelocidad;
  final Color textoEventoFrenada;
  final Color textoEventoAceleracion;
  final Color textoEventoGiro;
  final Color textoEventoVelocidad;
  final Color tinteEventoFrenada;
  final Color tinteEventoAceleracion;
  final Color tinteEventoGiro;
  final Color tinteEventoVelocidad;

  final LinearGradient gradienteScore;
  final LinearGradient gradienteRellenoGrafica;

  /// Texto, botón volver y líneas decorativas sobre `gradienteScore`.
  final Color textoSobreGradiente;
  final Color superficieSobreGradiente;
  final Color lineasSobreGradiente;

  /// Mapa del viaje (HU-29): borde tenue de la ruta y fondo de la atribución.
  final Color bordeRuta;
  final Color fondoAtribucion;

  final List<BoxShadow> sombraTarjeta;
  final List<BoxShadow> sombraBotonPrimario;
  final List<BoxShadow> sombraBotonAcento;
  final List<BoxShadow> resplandorPunto;

  static const claro = ColoresDriveSense(
    fondo: Color(0xFFEFEBE1),
    superficie: Color(0xFFFFFFFF),
    superficieAlt: Color(0xFFF9F7F2),
    borde: Color(0xFFE2DCCF),
    bordeFuerte: Color(0xFFDFD8C7),
    textoPrincipal: Color(0xFF1E252D),
    textoSecundario: Color(0xFF4B5661),
    textoTerciario: Color(0xFF7B8893),
    sobrePrimario: Color(0xFFFFFFFF),
    primario: Color(0xFF10B981),
    primarioOscuro: Color(0xFF059669),
    secundario: Color(0xFF0EA5E9),
    confort: Color(0xFF8B5CF6),
    peligro: Color(0xFFEF4444),
    advertencia: Color(0xFFF59E0B),
    botonPrimario: Color(0xFF047857),
    botonPrimarioPresionado: Color(0xFF065F46),
    enlace: Color(0xFF047857),
    fondoBotonSecundario: Color(0xFFE8E2D4),
    carril: Color(0xFFE8E2D4),
    barraNavegacion: Color(0xCCFFFFFF),
    bordePeligroSuave: Color(0xFFF8C9C9),
    textoPeligro: Color(0xFFB91C1C),
    textoExito: Color(0xFF047857),
    tintePrimario: Color(0xFFE7F8F2),
    tinteConfort: Color(0xFFF3EFFE),
    tintePeligro: Color(0xFFFDECEC),
    tinteAdvertencia: Color(0xFFFEF5E7),
    tinteNavActivo: Color(0xFFDBF4EC),
    tinteSecundario: Color(0xFFE2F4FC),
    encabezadoFondo: Color(0xFF1E252D),
    encabezadoSuperficie: Color(0xFF12171F),
    encabezadoBorde: Color(0xFF2A3440),
    encabezadoAcento: Color(0xFF34D399),
    encabezadoTexto: Color(0xFFF3F4F6),
    encabezadoTextoSecundario: Color(0xFF9CA3AF),
    acentoOscuroTenue: Color(0x2434D399),
    sobreAcentoOscuro: Color(0xFF12171F),
    eventoFrenada: Color(0xFFF87171),
    eventoAceleracion: Color(0xFFA78BFA),
    eventoGiro: Color(0xFFF59E0B),
    eventoVelocidad: Color(0xFF38BDF8),
    textoEventoFrenada: Color(0xFFB91C1C),
    textoEventoAceleracion: Color(0xFF6D28D9),
    textoEventoGiro: Color(0xFFB45309),
    textoEventoVelocidad: Color(0xFF0369A1),
    tinteEventoFrenada: Color(0xFFFDECEC),
    tinteEventoAceleracion: Color(0xFFF3EFFE),
    tinteEventoGiro: Color(0xFFFEF5E7),
    tinteEventoVelocidad: Color(0xFFE2F4FC),
    gradienteScore: LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    ),
    gradienteRellenoGrafica: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x2610B981), Color(0x0010B981)],
    ),
    textoSobreGradiente: Color(0xFF0B2A22),
    superficieSobreGradiente: Color(0x4DFFFFFF),
    lineasSobreGradiente: Color(0x59FFFFFF),
    bordeRuta: Color(0x400B2A22),
    fondoAtribucion: Color(0xCCFFFFFF),
    // blurRadius 16 en Flutter ≈ blur 20px de CSS (ver docs/diseno.md 3.3)
    sombraTarjeta: [
      BoxShadow(color: Color(0x0F000000), offset: Offset(0, 4), blurRadius: 16),
    ],
    sombraBotonPrimario: [
      BoxShadow(color: Color(0x3310B981), offset: Offset(0, 6), blurRadius: 16),
    ],
    sombraBotonAcento: [
      BoxShadow(color: Color(0x4034D399), offset: Offset(0, 6), blurRadius: 16),
    ],
    resplandorPunto: [
      BoxShadow(color: Color(0x6610B981), blurRadius: 12, spreadRadius: 2),
    ],
  );

  @override
  ColoresDriveSense copyWith({
    Color? fondo,
    Color? superficie,
    Color? superficieAlt,
    Color? borde,
    Color? bordeFuerte,
    Color? textoPrincipal,
    Color? textoSecundario,
    Color? textoTerciario,
    Color? sobrePrimario,
    Color? primario,
    Color? primarioOscuro,
    Color? secundario,
    Color? confort,
    Color? peligro,
    Color? advertencia,
    Color? botonPrimario,
    Color? botonPrimarioPresionado,
    Color? enlace,
    Color? fondoBotonSecundario,
    Color? carril,
    Color? barraNavegacion,
    Color? bordePeligroSuave,
    Color? textoPeligro,
    Color? textoExito,
    Color? tintePrimario,
    Color? tinteConfort,
    Color? tintePeligro,
    Color? tinteAdvertencia,
    Color? tinteNavActivo,
    Color? tinteSecundario,
    Color? encabezadoFondo,
    Color? encabezadoSuperficie,
    Color? encabezadoBorde,
    Color? encabezadoAcento,
    Color? encabezadoTexto,
    Color? encabezadoTextoSecundario,
    Color? acentoOscuroTenue,
    Color? sobreAcentoOscuro,
    Color? eventoFrenada,
    Color? eventoAceleracion,
    Color? eventoGiro,
    Color? eventoVelocidad,
    Color? textoEventoFrenada,
    Color? textoEventoAceleracion,
    Color? textoEventoGiro,
    Color? textoEventoVelocidad,
    Color? tinteEventoFrenada,
    Color? tinteEventoAceleracion,
    Color? tinteEventoGiro,
    Color? tinteEventoVelocidad,
    LinearGradient? gradienteScore,
    LinearGradient? gradienteRellenoGrafica,
    Color? textoSobreGradiente,
    Color? superficieSobreGradiente,
    Color? lineasSobreGradiente,
    Color? bordeRuta,
    Color? fondoAtribucion,
    List<BoxShadow>? sombraTarjeta,
    List<BoxShadow>? sombraBotonPrimario,
    List<BoxShadow>? sombraBotonAcento,
    List<BoxShadow>? resplandorPunto,
  }) {
    return ColoresDriveSense(
      fondo: fondo ?? this.fondo,
      superficie: superficie ?? this.superficie,
      superficieAlt: superficieAlt ?? this.superficieAlt,
      borde: borde ?? this.borde,
      bordeFuerte: bordeFuerte ?? this.bordeFuerte,
      textoPrincipal: textoPrincipal ?? this.textoPrincipal,
      textoSecundario: textoSecundario ?? this.textoSecundario,
      textoTerciario: textoTerciario ?? this.textoTerciario,
      sobrePrimario: sobrePrimario ?? this.sobrePrimario,
      primario: primario ?? this.primario,
      primarioOscuro: primarioOscuro ?? this.primarioOscuro,
      secundario: secundario ?? this.secundario,
      confort: confort ?? this.confort,
      peligro: peligro ?? this.peligro,
      advertencia: advertencia ?? this.advertencia,
      botonPrimario: botonPrimario ?? this.botonPrimario,
      botonPrimarioPresionado:
          botonPrimarioPresionado ?? this.botonPrimarioPresionado,
      enlace: enlace ?? this.enlace,
      fondoBotonSecundario: fondoBotonSecundario ?? this.fondoBotonSecundario,
      carril: carril ?? this.carril,
      barraNavegacion: barraNavegacion ?? this.barraNavegacion,
      bordePeligroSuave: bordePeligroSuave ?? this.bordePeligroSuave,
      textoPeligro: textoPeligro ?? this.textoPeligro,
      textoExito: textoExito ?? this.textoExito,
      tintePrimario: tintePrimario ?? this.tintePrimario,
      tinteConfort: tinteConfort ?? this.tinteConfort,
      tintePeligro: tintePeligro ?? this.tintePeligro,
      tinteAdvertencia: tinteAdvertencia ?? this.tinteAdvertencia,
      tinteNavActivo: tinteNavActivo ?? this.tinteNavActivo,
      tinteSecundario: tinteSecundario ?? this.tinteSecundario,
      encabezadoFondo: encabezadoFondo ?? this.encabezadoFondo,
      encabezadoSuperficie: encabezadoSuperficie ?? this.encabezadoSuperficie,
      encabezadoBorde: encabezadoBorde ?? this.encabezadoBorde,
      encabezadoAcento: encabezadoAcento ?? this.encabezadoAcento,
      encabezadoTexto: encabezadoTexto ?? this.encabezadoTexto,
      encabezadoTextoSecundario:
          encabezadoTextoSecundario ?? this.encabezadoTextoSecundario,
      acentoOscuroTenue: acentoOscuroTenue ?? this.acentoOscuroTenue,
      sobreAcentoOscuro: sobreAcentoOscuro ?? this.sobreAcentoOscuro,
      eventoFrenada: eventoFrenada ?? this.eventoFrenada,
      eventoAceleracion: eventoAceleracion ?? this.eventoAceleracion,
      eventoGiro: eventoGiro ?? this.eventoGiro,
      eventoVelocidad: eventoVelocidad ?? this.eventoVelocidad,
      textoEventoFrenada: textoEventoFrenada ?? this.textoEventoFrenada,
      textoEventoAceleracion:
          textoEventoAceleracion ?? this.textoEventoAceleracion,
      textoEventoGiro: textoEventoGiro ?? this.textoEventoGiro,
      textoEventoVelocidad: textoEventoVelocidad ?? this.textoEventoVelocidad,
      tinteEventoFrenada: tinteEventoFrenada ?? this.tinteEventoFrenada,
      tinteEventoAceleracion:
          tinteEventoAceleracion ?? this.tinteEventoAceleracion,
      tinteEventoGiro: tinteEventoGiro ?? this.tinteEventoGiro,
      tinteEventoVelocidad: tinteEventoVelocidad ?? this.tinteEventoVelocidad,
      gradienteScore: gradienteScore ?? this.gradienteScore,
      gradienteRellenoGrafica:
          gradienteRellenoGrafica ?? this.gradienteRellenoGrafica,
      textoSobreGradiente: textoSobreGradiente ?? this.textoSobreGradiente,
      superficieSobreGradiente:
          superficieSobreGradiente ?? this.superficieSobreGradiente,
      lineasSobreGradiente: lineasSobreGradiente ?? this.lineasSobreGradiente,
      bordeRuta: bordeRuta ?? this.bordeRuta,
      fondoAtribucion: fondoAtribucion ?? this.fondoAtribucion,
      sombraTarjeta: sombraTarjeta ?? this.sombraTarjeta,
      sombraBotonPrimario: sombraBotonPrimario ?? this.sombraBotonPrimario,
      sombraBotonAcento: sombraBotonAcento ?? this.sombraBotonAcento,
      resplandorPunto: resplandorPunto ?? this.resplandorPunto,
    );
  }

  @override
  ColoresDriveSense lerp(ColoresDriveSense? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return ColoresDriveSense(
      fondo: c(fondo, other.fondo),
      superficie: c(superficie, other.superficie),
      superficieAlt: c(superficieAlt, other.superficieAlt),
      borde: c(borde, other.borde),
      bordeFuerte: c(bordeFuerte, other.bordeFuerte),
      textoPrincipal: c(textoPrincipal, other.textoPrincipal),
      textoSecundario: c(textoSecundario, other.textoSecundario),
      textoTerciario: c(textoTerciario, other.textoTerciario),
      sobrePrimario: c(sobrePrimario, other.sobrePrimario),
      primario: c(primario, other.primario),
      primarioOscuro: c(primarioOscuro, other.primarioOscuro),
      secundario: c(secundario, other.secundario),
      confort: c(confort, other.confort),
      peligro: c(peligro, other.peligro),
      advertencia: c(advertencia, other.advertencia),
      botonPrimario: c(botonPrimario, other.botonPrimario),
      botonPrimarioPresionado: c(
        botonPrimarioPresionado,
        other.botonPrimarioPresionado,
      ),
      enlace: c(enlace, other.enlace),
      fondoBotonSecundario: c(fondoBotonSecundario, other.fondoBotonSecundario),
      carril: c(carril, other.carril),
      barraNavegacion: c(barraNavegacion, other.barraNavegacion),
      bordePeligroSuave: c(bordePeligroSuave, other.bordePeligroSuave),
      textoPeligro: c(textoPeligro, other.textoPeligro),
      textoExito: c(textoExito, other.textoExito),
      tintePrimario: c(tintePrimario, other.tintePrimario),
      tinteConfort: c(tinteConfort, other.tinteConfort),
      tintePeligro: c(tintePeligro, other.tintePeligro),
      tinteAdvertencia: c(tinteAdvertencia, other.tinteAdvertencia),
      tinteNavActivo: c(tinteNavActivo, other.tinteNavActivo),
      tinteSecundario: c(tinteSecundario, other.tinteSecundario),
      encabezadoFondo: c(encabezadoFondo, other.encabezadoFondo),
      encabezadoSuperficie: c(encabezadoSuperficie, other.encabezadoSuperficie),
      encabezadoBorde: c(encabezadoBorde, other.encabezadoBorde),
      encabezadoAcento: c(encabezadoAcento, other.encabezadoAcento),
      encabezadoTexto: c(encabezadoTexto, other.encabezadoTexto),
      encabezadoTextoSecundario: c(
        encabezadoTextoSecundario,
        other.encabezadoTextoSecundario,
      ),
      acentoOscuroTenue: c(acentoOscuroTenue, other.acentoOscuroTenue),
      sobreAcentoOscuro: c(sobreAcentoOscuro, other.sobreAcentoOscuro),
      eventoFrenada: c(eventoFrenada, other.eventoFrenada),
      eventoAceleracion: c(eventoAceleracion, other.eventoAceleracion),
      eventoGiro: c(eventoGiro, other.eventoGiro),
      eventoVelocidad: c(eventoVelocidad, other.eventoVelocidad),
      textoEventoFrenada: c(textoEventoFrenada, other.textoEventoFrenada),
      textoEventoAceleracion: c(
        textoEventoAceleracion,
        other.textoEventoAceleracion,
      ),
      textoEventoGiro: c(textoEventoGiro, other.textoEventoGiro),
      textoEventoVelocidad: c(textoEventoVelocidad, other.textoEventoVelocidad),
      tinteEventoFrenada: c(tinteEventoFrenada, other.tinteEventoFrenada),
      tinteEventoAceleracion: c(
        tinteEventoAceleracion,
        other.tinteEventoAceleracion,
      ),
      tinteEventoGiro: c(tinteEventoGiro, other.tinteEventoGiro),
      tinteEventoVelocidad: c(tinteEventoVelocidad, other.tinteEventoVelocidad),
      gradienteScore: LinearGradient.lerp(
        gradienteScore,
        other.gradienteScore,
        t,
      )!,
      gradienteRellenoGrafica: LinearGradient.lerp(
        gradienteRellenoGrafica,
        other.gradienteRellenoGrafica,
        t,
      )!,
      textoSobreGradiente: c(textoSobreGradiente, other.textoSobreGradiente),
      superficieSobreGradiente: c(
        superficieSobreGradiente,
        other.superficieSobreGradiente,
      ),
      lineasSobreGradiente: c(lineasSobreGradiente, other.lineasSobreGradiente),
      bordeRuta: c(bordeRuta, other.bordeRuta),
      fondoAtribucion: c(fondoAtribucion, other.fondoAtribucion),
      sombraTarjeta: s(sombraTarjeta, other.sombraTarjeta),
      sombraBotonPrimario: s(sombraBotonPrimario, other.sombraBotonPrimario),
      sombraBotonAcento: s(sombraBotonAcento, other.sombraBotonAcento),
      resplandorPunto: s(resplandorPunto, other.resplandorPunto),
    );
  }
}
