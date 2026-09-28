import 'package:flutter/material.dart';

import '../design/design.dart';

/// Círculo oscuro con las iniciales del usuario (docs/diseno.md, 7.1).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nombre, this.grande = false});

  final String nombre;

  /// 64 dp (Perfil) en vez de 44 (cabecera de Inicio).
  final bool grande;

  /// Primera letra de las dos primeras palabras: "Ana María Pérez" → "AM".
  static String iniciales(String nombre) => nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((palabra) => palabra.isNotEmpty)
      .take(2)
      .map((palabra) => palabra[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final lado = grande ? Medidas.avatarGrande : Medidas.avatar;

    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colores.encabezadoFondo,
        shape: BoxShape.circle,
      ),
      child: Text(
        iniciales(nombre),
        style: (grande ? tipografia.titulo : tipografia.subtitulo).copyWith(
          color: colores.encabezadoAcento,
        ),
      ),
    );
  }
}
