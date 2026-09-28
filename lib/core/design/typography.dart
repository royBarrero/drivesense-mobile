import 'package:flutter/material.dart';

/// Familias declaradas en pubspec.yaml.
abstract final class Fuentes {
  static const interfaz = 'PlusJakartaSans';
  static const numeros = 'SpaceGrotesk';
}

/// Estilos tipográficos de DriveSense (docs/diseno.md, sección 2).
///
/// No llevan color: se aplica según el contexto con `copyWith(color: ...)`,
/// o lo hereda del `DefaultTextStyle`.
@immutable
class TipografiaDriveSense extends ThemeExtension<TipografiaDriveSense> {
  const TipografiaDriveSense({
    required this.velocimetro,
    required this.telemetriaXL,
    required this.numeroGrande,
    required this.telemetria,
    required this.puntaje,
    required this.numeroMetrica,
    required this.tituloHero,
    required this.tituloGrande,
    required this.titulo,
    required this.tituloTarjeta,
    required this.marca,
    required this.subtituloGrande,
    required this.subtitulo,
    required this.cuerpo,
    required this.cuerpoPequeno,
    required this.boton,
    required this.etiquetaCampo,
    required this.ayuda,
    required this.etiqueta,
    required this.etiquetaGrande,
  });

  // Space Grotesk: números de telemetría y puntajes
  final TextStyle velocimetro;
  final TextStyle telemetriaXL;
  final TextStyle numeroGrande;
  final TextStyle telemetria;
  final TextStyle puntaje;
  final TextStyle numeroMetrica;

  // Plus Jakarta Sans: interfaz
  final TextStyle tituloHero;
  final TextStyle tituloGrande;
  final TextStyle titulo;
  final TextStyle tituloTarjeta;
  final TextStyle marca;
  final TextStyle subtituloGrande;
  final TextStyle subtitulo;
  final TextStyle cuerpo;
  final TextStyle cuerpoPequeno;
  final TextStyle boton;
  final TextStyle etiquetaCampo;
  final TextStyle ayuda;

  /// En mayúsculas: usar el widget `Etiqueta` cuando exista.
  final TextStyle etiqueta;
  final TextStyle etiquetaGrande;

  static const base = TipografiaDriveSense(
    velocimetro: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 120,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    numeroGrande: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
    tituloGrande: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    telemetriaXL: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 64,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    telemetria: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 56,
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    puntaje: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
    numeroMetrica: TextStyle(
      fontFamily: Fuentes.numeros,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
    tituloHero: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    titulo: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    tituloTarjeta: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    marca: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    subtituloGrande: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    subtitulo: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    cuerpo: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    cuerpoPequeno: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    boton: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    etiquetaCampo: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    ayuda: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    etiqueta: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.55,
    ),
    etiquetaGrande: TextStyle(
      fontFamily: Fuentes.interfaz,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
    ),
  );

  /// `TextTheme` de Material según la tabla de correspondencia de la guía.
  TextTheme comoTextTheme() => TextTheme(
    headlineSmall: titulo,
    titleLarge: subtituloGrande,
    titleMedium: subtitulo,
    bodyLarge: cuerpo,
    bodyMedium: cuerpo,
    bodySmall: cuerpoPequeno,
    labelLarge: boton,
    labelMedium: etiquetaGrande,
    labelSmall: etiqueta,
  );

  @override
  TipografiaDriveSense copyWith({
    TextStyle? velocimetro,
    TextStyle? telemetriaXL,
    TextStyle? numeroGrande,
    TextStyle? tituloGrande,
    TextStyle? telemetria,
    TextStyle? puntaje,
    TextStyle? numeroMetrica,
    TextStyle? tituloHero,
    TextStyle? titulo,
    TextStyle? tituloTarjeta,
    TextStyle? marca,
    TextStyle? subtituloGrande,
    TextStyle? subtitulo,
    TextStyle? cuerpo,
    TextStyle? cuerpoPequeno,
    TextStyle? boton,
    TextStyle? etiquetaCampo,
    TextStyle? ayuda,
    TextStyle? etiqueta,
    TextStyle? etiquetaGrande,
  }) {
    return TipografiaDriveSense(
      velocimetro: velocimetro ?? this.velocimetro,
      telemetriaXL: telemetriaXL ?? this.telemetriaXL,
      numeroGrande: numeroGrande ?? this.numeroGrande,
      tituloGrande: tituloGrande ?? this.tituloGrande,
      telemetria: telemetria ?? this.telemetria,
      puntaje: puntaje ?? this.puntaje,
      numeroMetrica: numeroMetrica ?? this.numeroMetrica,
      tituloHero: tituloHero ?? this.tituloHero,
      titulo: titulo ?? this.titulo,
      tituloTarjeta: tituloTarjeta ?? this.tituloTarjeta,
      marca: marca ?? this.marca,
      subtituloGrande: subtituloGrande ?? this.subtituloGrande,
      subtitulo: subtitulo ?? this.subtitulo,
      cuerpo: cuerpo ?? this.cuerpo,
      cuerpoPequeno: cuerpoPequeno ?? this.cuerpoPequeno,
      boton: boton ?? this.boton,
      etiquetaCampo: etiquetaCampo ?? this.etiquetaCampo,
      ayuda: ayuda ?? this.ayuda,
      etiqueta: etiqueta ?? this.etiqueta,
      etiquetaGrande: etiquetaGrande ?? this.etiquetaGrande,
    );
  }

  @override
  TipografiaDriveSense lerp(TipografiaDriveSense? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return TipografiaDriveSense(
      velocimetro: l(velocimetro, other.velocimetro),
      telemetriaXL: l(telemetriaXL, other.telemetriaXL),
      numeroGrande: l(numeroGrande, other.numeroGrande),
      tituloGrande: l(tituloGrande, other.tituloGrande),
      telemetria: l(telemetria, other.telemetria),
      puntaje: l(puntaje, other.puntaje),
      numeroMetrica: l(numeroMetrica, other.numeroMetrica),
      tituloHero: l(tituloHero, other.tituloHero),
      titulo: l(titulo, other.titulo),
      tituloTarjeta: l(tituloTarjeta, other.tituloTarjeta),
      marca: l(marca, other.marca),
      subtituloGrande: l(subtituloGrande, other.subtituloGrande),
      subtitulo: l(subtitulo, other.subtitulo),
      cuerpo: l(cuerpo, other.cuerpo),
      cuerpoPequeno: l(cuerpoPequeno, other.cuerpoPequeno),
      boton: l(boton, other.boton),
      etiquetaCampo: l(etiquetaCampo, other.etiquetaCampo),
      ayuda: l(ayuda, other.ayuda),
      etiqueta: l(etiqueta, other.etiqueta),
      etiquetaGrande: l(etiquetaGrande, other.etiquetaGrande),
    );
  }
}
