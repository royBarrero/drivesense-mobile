import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/design/design.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../models/route_plan.dart';
import '../../providers/navigation_provider.dart';

/// Abre la búsqueda por nombre; devuelve el lugar elegido o `null`.
Future<Lugar?> buscarDestino(BuildContext context) =>
    showModalBottomSheet<Lugar>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const HojaBuscarDestino(),
    );

/// Mínimo de caracteres de la búsqueda (como el backend).
const minimoBusqueda = 3;

/// Hoja "Buscar destino": un campo y el botón "Buscar". Sin autocompletar:
/// solo se consulta al enviar.
class HojaBuscarDestino extends ConsumerStatefulWidget {
  const HojaBuscarDestino({super.key});

  @override
  ConsumerState<HojaBuscarDestino> createState() => _HojaBuscarDestinoState();
}

class _HojaBuscarDestinoState extends ConsumerState<HojaBuscarDestino> {
  final _texto = TextEditingController();

  /// Texto enviado (normalizado); nulo antes de la primera búsqueda.
  String? _consulta;
  String? _errorLocal;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() {
    final texto = _texto.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (texto.length < minimoBusqueda) {
      setState(() => _errorLocal = 'Escribe al menos $minimoBusqueda letras.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _errorLocal = null;
      _consulta = texto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    final consulta = _consulta;
    final resultado = consulta == null
        ? null
        : ref.watch(lugaresProvider(consulta));
    final cargando = resultado?.isLoading ?? false;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Espacios.l,
              0,
              Espacios.l,
              Espacios.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buscar destino',
                  style: tipografia.subtituloGrande.copyWith(
                    color: colores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: Espacios.xxs),
                Text(
                  'Lugares de Bolivia, primero los de Santa Cruz.',
                  style: tipografia.cuerpoPequeno.copyWith(
                    color: colores.textoSecundario,
                  ),
                ),
                const SizedBox(height: Espacios.m),
                TextField(
                  controller: _texto,
                  autofocus: true,
                  maxLength: 100,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _buscar(),
                  style: tipografia.cuerpo.copyWith(
                    color: colores.textoPrincipal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Lugar, calle o barrio',
                    counterText: '',
                    errorText: _errorLocal,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colores.textoSecundario,
                    ),
                  ),
                ),
                const SizedBox(height: Espacios.s),
                BotonPrimario(
                  texto: 'Buscar',
                  icono: Icons.search_rounded,
                  cargando: cargando,
                  alPresionar: _buscar,
                ),
                if (resultado != null && !cargando) ...[
                  const SizedBox(height: Espacios.l),
                  ...switch (resultado) {
                    AsyncData(value: final lugares) when lugares.isEmpty => [
                      Text(
                        'No encontramos lugares con ese nombre. Prueba con '
                        'otras palabras o toca el mapa.',
                        style: tipografia.cuerpo.copyWith(
                          color: colores.textoSecundario,
                        ),
                      ),
                    ],
                    AsyncData(value: final lugares) => [
                      for (final lugar in lugares)
                        _FilaLugar(
                          lugar: lugar,
                          alElegir: () => Navigator.pop(context, lugar),
                        ),
                    ],
                    AsyncError(:final error) => [
                      AvisoError(mensaje: _mensaje(error)),
                    ],
                    _ => const <Widget>[],
                  },
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _mensaje(Object error) => switch (error) {
    ErrorNavegacion(:final mensaje) => mensaje,
    ErrorApi(:final mensaje) => mensaje,
    _ => ErrorApi.inesperado,
  };
}

class _FilaLugar extends StatelessWidget {
  const _FilaLugar({required this.lugar, required this.alElegir});

  final Lugar lugar;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;
    return InkWell(
      onTap: alElegir,
      borderRadius: BorderRadius.circular(Radios.micro),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacios.xs),
        child: Row(
          children: [
            Container(
              width: Medidas.cajaIcono,
              height: Medidas.cajaIcono,
              decoration: BoxDecoration(
                color: colores.tinteSecundario,
                borderRadius: BorderRadius.circular(Radios.cajaIcono),
              ),
              child: Icon(
                Icons.place_outlined,
                size: Medidas.icono,
                color: colores.textoEventoVelocidad,
              ),
            ),
            const SizedBox(width: Espacios.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lugar.nombre,
                    style: tipografia.cuerpo.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colores.textoPrincipal,
                    ),
                  ),
                  Text(
                    lugar.direccion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tipografia.cuerpoPequeno.copyWith(
                      color: colores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
