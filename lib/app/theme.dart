import 'package:flutter/material.dart';

import '../core/design/design.dart';

/// Tema claro. El oscuro será `_construirTema(ColoresDriveSense.oscuro, Brightness.dark)`.
ThemeData temaClaro() =>
    _construirTema(ColoresDriveSense.claro, Brightness.light);

ThemeData _construirTema(ColoresDriveSense c, Brightness brillo) {
  const t = TipografiaDriveSense.base;
  final textTheme = t.comoTextTheme().apply(
    bodyColor: c.textoPrincipal,
    displayColor: c.textoPrincipal,
  );

  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radios.campo),
    borderSide: BorderSide(color: c.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    fontFamily: Fuentes.interfaz,
    scaffoldBackgroundColor: c.fondo,
    // Manual, sin fromSeed: los colores deben ser exactamente los de la guía
    colorScheme: ColorScheme(
      brightness: brillo,
      primary: c.primario,
      onPrimary: c.sobrePrimario,
      secondary: c.secundario,
      onSecondary: c.sobrePrimario,
      error: c.peligro,
      onError: c.sobrePrimario,
      surface: c.superficie,
      onSurface: c.textoPrincipal,
      onSurfaceVariant: c.textoSecundario,
      outline: c.borde,
      outlineVariant: c.bordeFuerte,
    ),
    textTheme: textTheme,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.botonPrimario,
      selectionHandleColor: c.botonPrimario,
      selectionColor: c.tintePrimario,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.botonPrimario),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.fromHeight(Medidas.altoBotonFormulario),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Espacios.xl, vertical: 14),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(t.boton),
        backgroundColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) {
            return c.fondoBotonSecundario;
          }
          if (estados.contains(WidgetState.pressed)) {
            return c.botonPrimarioPresionado;
          }
          return c.botonPrimario;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return c.textoSecundario;
          return c.sobrePrimario;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.enlace,
        textStyle: t.cuerpo.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficieAlt,
      hintStyle: t.cuerpo.copyWith(color: c.textoTerciario),
      // (52 - 21 de línea) / 2 ≈ 15.5 → campos de 52 de alto
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espacios.m,
        vertical: 15.5,
      ),
      border: bordeCampo,
      enabledBorder: bordeCampo,
      disabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: c.botonPrimario, width: 1.5),
      ),
      errorBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: c.peligro),
      ),
      focusedErrorBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: c.peligro, width: 1.5),
      ),
    ),
    extensions: [c, t],
  );
}
