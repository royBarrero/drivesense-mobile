import 'package:flutter/material.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/design/design.dart';

/// Aviso cuando no se pudo cargar el historial o un viaje, con "Reintentar".
///
/// Sin conexión (sin respuesta del servidor) lo dice así; si no, muestra el
/// mensaje de la API.
class ErrorCarga extends StatelessWidget {
  const ErrorCarga({
    super.key,
    required this.error,
    required this.alReintentar,
  });

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final api = error is ErrorApi ? error as ErrorApi : null;
    final sinConexion = api != null && api.codigo == null;

    return Padding(
      padding: const EdgeInsets.all(Espacios.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Medidas.circuloEstado,
            height: Medidas.circuloEstado,
            decoration: BoxDecoration(
              color: colores.tinteAdvertencia,
              shape: BoxShape.circle,
            ),
            child: Icon(
              sinConexion ? Icons.wifi_off_rounded : Icons.error_outline,
              size: Medidas.iconoEstado,
              color: colores.advertencia,
            ),
          ),
          const SizedBox(height: Espacios.m),
          Text(
            sinConexion ? 'Sin conexión' : 'No se pudo cargar',
            textAlign: TextAlign.center,
            style: tipografia.subtituloGrande.copyWith(
              color: colores.textoPrincipal,
            ),
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            sinConexion
                ? 'Revisa tu conexión a internet e intenta de nuevo.'
                : api?.mensaje ?? ErrorApi.inesperado,
            textAlign: TextAlign.center,
            style: tipografia.cuerpo.copyWith(color: colores.textoSecundario),
          ),
          const SizedBox(height: Espacios.l),
          OutlinedButton.icon(
            onPressed: alReintentar,
            icon: const Icon(Icons.refresh_rounded, size: Medidas.icono),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
