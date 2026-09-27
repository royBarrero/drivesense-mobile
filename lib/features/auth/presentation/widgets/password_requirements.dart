import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../models/register_validation.dart';

/// Lista de requisitos de la contraseña que se marcan al cumplirse
/// (docs/diseno.md, 4.2).
class ListaRequisitosContrasenia extends StatelessWidget {
  const ListaRequisitosContrasenia({
    super.key,
    required this.requisitos,
    this.resaltarPendientes = false,
  });

  final RequisitosContrasenia requisitos;

  /// En rojo los pendientes (cuando el usuario ya salió del campo).
  final bool resaltarPendientes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Requisito(
          'Al menos 8 caracteres',
          requisitos.largo,
          resaltarPendientes,
        ),
        _Requisito('Al menos una letra', requisitos.letra, resaltarPendientes),
        _Requisito('Al menos un número', requisitos.numero, resaltarPendientes),
      ],
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, this.cumplido, this.resaltarPendiente);

  final String texto;
  final bool cumplido;
  final bool resaltarPendiente;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final color = cumplido
        ? colores.textoExito
        : resaltarPendiente
        ? colores.textoPeligro
        : colores.textoTerciario;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
            size: Medidas.iconoPequeno,
            color: color,
          ),
          const SizedBox(width: Espacios.xs - 2),
          Text(texto, style: context.tipografia.ayuda.copyWith(color: color)),
        ],
      ),
    );
  }
}
