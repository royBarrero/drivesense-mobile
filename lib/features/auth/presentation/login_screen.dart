import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/api/api_error.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/form_field.dart';
import '../providers/session_provider.dart';
import 'widgets/auth_layout.dart';

/// Inicio de sesión del conductor (HU-02).
class LoginPantalla extends ConsumerStatefulWidget {
  const LoginPantalla({super.key});

  @override
  ConsumerState<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends ConsumerState<LoginPantalla> {
  final _email = TextEditingController();
  final _contrasenia = TextEditingController();

  bool _ocultarContrasenia = true;
  bool _cargando = false;

  /// Error general (401, 403, sin conexión...): aviso arriba y ambos campos en rojo.
  String? _errorGeneral;

  /// Errores por campo (422), con el mensaje de la API.
  String? _errorEmail;
  String? _errorContrasenia;

  bool get _camposCompletos =>
      _email.text.trim().isNotEmpty && _contrasenia.text.isNotEmpty;

  @override
  void dispose() {
    _email.dispose();
    _contrasenia.dispose();
    super.dispose();
  }

  void _alCambiarCampo(String _) {
    setState(() {
      _errorGeneral = null;
      _errorEmail = null;
      _errorContrasenia = null;
    });
  }

  Future<void> _iniciarSesion() async {
    if (!_camposCompletos || _cargando) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);

    try {
      await ref
          .read(sesionProvider.notifier)
          .iniciarSesion(email: _email.text, contrasenia: _contrasenia.text);
      // Si todo va bien, las rutas redirigen solas según la sesión
    } on ErrorApi catch (e) {
      if (!mounted) return;
      setState(() {
        final errorEmail = e.mensajeDeCampo('email');
        final errorContrasenia = e.mensajeDeCampo('contrasenia');
        if (errorEmail != null || errorContrasenia != null) {
          _errorEmail = errorEmail;
          _errorContrasenia = errorContrasenia;
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final tipografia = context.tipografia;

    return PantallaAuth(
      titulo: 'Cada viaje cuenta.',
      subtitulo: 'Tu teléfono mide cómo conduces, sin hardware extra.',
      altoEncabezado: Medidas.altoEncabezadoLogin,
      tarjeta: _tarjetaFormulario(colores, tipografia),
      pie: _pie(colores, tipografia),
    );
  }

  Widget _tarjetaFormulario(
    ColoresDriveSense colores,
    TipografiaDriveSense tipografia,
  ) {
    final hayErrorGeneral = _errorGeneral != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Espacios.m),
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.xl,
      ),
      decoration: BoxDecoration(
        color: colores.superficie,
        borderRadius: BorderRadius.circular(Radios.tarjetaDestacada),
        border: Border.all(color: colores.borde),
        boxShadow: colores.sombraTarjeta,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inicia sesión',
              style: tipografia.tituloTarjeta.copyWith(
                color: colores.textoPrincipal,
              ),
            ),
            const SizedBox(height: Espacios.l),
            if (hayErrorGeneral) ...[
              AvisoError(mensaje: _errorGeneral!),
              const SizedBox(height: Espacios.m),
            ],
            CampoFormulario(
              etiqueta: 'Correo electrónico',
              controlador: _email,
              conError: hayErrorGeneral,
              mensajeError: _errorEmail,
              habilitado: !_cargando,
              teclado: TextInputType.emailAddress,
              accionTeclado: TextInputAction.next,
              autocompletado: const [AutofillHints.email],
              alCambiar: _alCambiarCampo,
            ),
            const SizedBox(height: Espacios.m),
            CampoFormulario(
              etiqueta: 'Contraseña',
              controlador: _contrasenia,
              conError: hayErrorGeneral,
              mensajeError: _errorContrasenia,
              habilitado: !_cargando,
              ocultarTexto: _ocultarContrasenia,
              accionTeclado: TextInputAction.done,
              autocompletado: const [AutofillHints.password],
              alCambiar: _alCambiarCampo,
              alEnviar: (_) => _iniciarSesion(),
              sufijo: IconButton(
                onPressed: () =>
                    setState(() => _ocultarContrasenia = !_ocultarContrasenia),
                tooltip: _ocultarContrasenia
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _ocultarContrasenia
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: Medidas.icono,
                  color: colores.textoTerciario,
                ),
              ),
            ),
            const SizedBox(height: Espacios.xl),
            BotonPrimario(
              texto: 'Iniciar sesión',
              cargando: _cargando,
              alPresionar: _camposCompletos ? _iniciarSesion : null,
            ),
            if (!_camposCompletos) ...[
              const SizedBox(height: Espacios.xs),
              Text(
                'Completa ambos campos para continuar',
                textAlign: TextAlign.center,
                style: tipografia.ayuda.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pie(ColoresDriveSense colores, TipografiaDriveSense tipografia) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Espacios.xxl,
        0,
        Espacios.xxl,
        Espacios.xl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        children: [
          // Wrap: si no cabe (letra grande de accesibilidad), "Crear cuenta" baja de línea
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '¿No tienes cuenta?',
                style: tipografia.cuerpo.copyWith(
                  color: colores.textoSecundario,
                ),
              ),
              TextButton(
                onPressed: _cargando
                    ? null
                    : () => context.push(Rutas.registro),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
          const SizedBox(height: Espacios.xxs),
          Text(
            'Si tu empresa creó tu cuenta, usa la contraseña temporal que te entregó.',
            textAlign: TextAlign.center,
            style: tipografia.ayuda.copyWith(color: colores.textoSecundario),
          ),
        ],
      ),
    );
  }
}
