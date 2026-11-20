import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/screen_header.dart';
import '../../recomendaciones/presentation/widgets/recommendation_card.dart';
import '../models/assistant_message.dart';
import '../providers/assistant_provider.dart';

/// Tope de la pregunta (el del backend).
const maximoPregunta = 500;

const saludoAsistente =
    'Hola, soy el asistente de DriveSense. Pregúntame cómo usar la app: '
    'iniciar un viaje, ver tus puntajes, tu historial y más.';

/// Asistente de ayuda: responde cómo usar la app (docs/diseno.md, 7.1). No
/// ve los viajes ni los puntajes del conductor.
class AsistentePantalla extends ConsumerStatefulWidget {
  const AsistentePantalla({super.key});

  @override
  ConsumerState<AsistentePantalla> createState() => _AsistentePantallaState();
}

class _AsistentePantallaState extends ConsumerState<AsistentePantalla> {
  final _campo = TextEditingController();
  final _desplazamiento = ScrollController();

  @override
  void dispose() {
    _campo.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  void _enviar([String? texto]) {
    final pregunta = (texto ?? _campo.text).trim();
    if (pregunta.isEmpty) return;
    _campo.clear();
    ref.read(asistenteProvider.notifier).preguntar(pregunta);
  }

  /// Baja hasta el último mensaje después de dibujarlo.
  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_desplazamiento.hasClients) return;
      _desplazamiento.animateTo(
        _desplazamiento.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estado = ref.watch(asistenteProvider);
    ref.listen(asistenteProvider, (anterior, siguiente) {
      if (anterior?.mensajes.length != siguiente.mensajes.length ||
          anterior?.enviando != siguiente.enviando ||
          anterior?.error != siguiente.error) {
        _bajar();
      }
    });
    final sugerencias = ref.watch(sugerenciasAsistenteProvider).value ?? [];

    // Íconos oscuros en la barra de estado (Inicio los deja claros)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colores.fondo,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacios.l,
                  Espacios.m,
                  Espacios.s,
                  Espacios.s,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: CabeceraPantalla(
                        titulo: 'Asistente de ayuda',
                        alternativa: Rutas.inicio,
                      ),
                    ),
                    if (estado.mensajes.isNotEmpty)
                      IconButton(
                        tooltip: 'Nueva conversación',
                        onPressed: estado.enviando
                            ? null
                            : () =>
                                  ref.read(asistenteProvider.notifier).nueva(),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: Medidas.iconoNavegacion,
                          color: colores.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _desplazamiento,
                  padding: const EdgeInsets.fromLTRB(
                    Espacios.l,
                    Espacios.xs,
                    Espacios.l,
                    Espacios.l,
                  ),
                  children: [
                    const _Burbuja(
                      mensaje: MensajeAsistente(
                        rol: RolMensaje.asistente,
                        texto: saludoAsistente,
                      ),
                    ),
                    if (estado.mensajes.isEmpty && sugerencias.isNotEmpty) ...[
                      const SizedBox(height: Espacios.s),
                      Wrap(
                        spacing: Espacios.xs,
                        runSpacing: Espacios.xs,
                        children: [
                          for (final s in sugerencias)
                            _ChipSugerencia(
                              texto: s,
                              alTocar: () => _enviar(s),
                            ),
                        ],
                      ),
                    ],
                    for (final mensaje in estado.mensajes) ...[
                      const SizedBox(height: Espacios.xs),
                      _Burbuja(mensaje: mensaje),
                    ],
                    if (estado.enviando) ...[
                      const SizedBox(height: Espacios.xs),
                      const _Escribiendo(),
                    ],
                    if (estado.error != null) ...[
                      const SizedBox(height: Espacios.s),
                      AvisoError(mensaje: estado.error!),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              ref.read(asistenteProvider.notifier).reintentar(),
                          child: const Text('Reintentar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _BarraPregunta(
                campo: _campo,
                enviando: estado.enviando,
                alEnviar: _enviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeAsistente mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final delUsuario = mensaje.esDelUsuario;
    const radio = Radius.circular(Radios.micro);
    const cola = Radius.circular(Radios.colaBurbuja);

    return LayoutBuilder(
      builder: (context, restricciones) => Align(
        alignment: delUsuario ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: restricciones.maxWidth * Medidas.fraccionAnchoBurbuja,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacios.m,
              vertical: Espacios.s,
            ),
            decoration: BoxDecoration(
              color: delUsuario ? colores.encabezadoFondo : colores.superficie,
              border: delUsuario ? null : Border.all(color: colores.borde),
              borderRadius: BorderRadius.only(
                topLeft: delUsuario ? radio : cola,
                topRight: delUsuario ? cola : radio,
                bottomLeft: radio,
                bottomRight: radio,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  mensaje.texto,
                  style: context.tipografia.cuerpo.copyWith(
                    color: delUsuario
                        ? colores.encabezadoTexto
                        : colores.textoPrincipal,
                  ),
                ),
                if (mensaje.generadaPorIa) ...[
                  const SizedBox(height: Espacios.xs),
                  const CapsulaIA(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Espacios.m,
          vertical: Espacios.s,
        ),
        decoration: BoxDecoration(
          color: colores.superficie,
          border: Border.all(color: colores.borde),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Radios.colaBurbuja),
            topRight: Radius.circular(Radios.micro),
            bottomLeft: Radius.circular(Radios.micro),
            bottomRight: Radius.circular(Radios.micro),
          ),
        ),
        child: Text(
          'Escribiendo…',
          style: context.tipografia.cuerpoPequeno.copyWith(
            color: colores.textoSecundario,
          ),
        ),
      ),
    );
  }
}

class _ChipSugerencia extends StatelessWidget {
  const _ChipSugerencia({required this.texto, required this.alTocar});

  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Material(
      color: colores.superficie,
      shape: StadiumBorder(side: BorderSide(color: colores.bordeFuerte)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacios.s,
            vertical: Espacios.xs,
          ),
          child: Text(
            texto,
            style: context.tipografia.cuerpoPequeno.copyWith(
              color: colores.textoPrincipal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarraPregunta extends StatelessWidget {
  const _BarraPregunta({
    required this.campo,
    required this.enviando,
    required this.alEnviar,
  });

  final TextEditingController campo;
  final bool enviando;
  final VoidCallback alEnviar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.m,
        vertical: Espacios.s,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        border: Border(top: BorderSide(color: colores.borde)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: campo,
              minLines: 1,
              maxLines: 4,
              maxLength: maximoPregunta,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => alEnviar(),
              decoration: const InputDecoration(
                hintText: 'Escribe tu pregunta',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: Espacios.xs),
          ValueListenableBuilder(
            valueListenable: campo,
            builder: (context, valor, _) {
              final activo = !enviando && valor.text.trim().isNotEmpty;
              return Material(
                color: activo ? colores.botonPrimario : colores.carril,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: activo ? alEnviar : null,
                  child: SizedBox.square(
                    dimension: Medidas.botonVolver,
                    child: Icon(
                      Icons.send_rounded,
                      size: Medidas.icono,
                      color: colores.sobrePrimario,
                      semanticLabel: 'Enviar',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
