import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/api/api_error.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/register_validation.dart';
import '../providers/session_provider.dart';
import 'widgets/auth_layout.dart';
import 'widgets/password_requirements.dart';

/// Campos del formulario. Los nombres coinciden con los `campo` de la API
/// (salvo `confirmacion`, que solo existe en la app).
enum _Campo { nombre, email, telefono, contrasenia, confirmacion }

/// Registro de conductor (HU-01).
class RegistroPantalla extends ConsumerStatefulWidget {
  const RegistroPantalla({super.key});

  @override
  ConsumerState<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends ConsumerState<RegistroPantalla> {
  final _controladores = {
    for (final campo in _Campo.values) campo: TextEditingController(),
  };

  /// Campos de los que el usuario ya salió: solo en ellos se muestran errores locales.
  final _tocados = <_Campo>{};

  /// Errores devueltos por la API (409, 422), por campo.
  final _erroresServidor = <_Campo, String>{};

  /// Sin conexión u otros errores: aviso arriba del formulario.
  String? _errorGeneral;

  bool _cargando = false;
  bool _ocultarContrasenia = true;
  bool _ocultarConfirmacion = true;

  String _texto(_Campo campo) => _controladores[campo]!.text;

  RequisitosContrasenia get _requisitos =>
      RequisitosContrasenia(_texto(_Campo.contrasenia));

  /// Error local del campo, calculado siempre (se muestra solo si está tocado).
  String? _errorLocal(_Campo campo) => switch (campo) {
    _Campo.nombre => validarNombre(_texto(campo)),
    _Campo.email => validarCorreo(_texto(campo)),
    _Campo.telefono => validarTelefono(_texto(campo)),
    // Sin mensaje: los requisitos pendientes se marcan en rojo en la lista
    _Campo.contrasenia => null,
    _Campo.confirmacion => validarConfirmacion(
      _texto(_Campo.contrasenia),
      _texto(campo),
    ),
  };

  bool get _formularioValido =>
      _requisitos.cumple && _Campo.values.every((c) => _errorLocal(c) == null);

  String? _mensajeVisible(_Campo campo) {
    final local = _tocados.contains(campo) ? _errorLocal(campo) : null;
    return local ?? _erroresServidor[campo];
  }

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  void _alCambiar(_Campo campo) {
    setState(() {
      _erroresServidor.remove(campo);
      _errorGeneral = null;
    });
  }

  void _alSalir(_Campo campo) => setState(() => _tocados.add(campo));

  void _volverAlLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Rutas.login);
    }
  }

  Future<void> _registrarse() async {
    if (!_formularioValido || _cargando) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);

    try {
      await ref
          .read(sesionProvider.notifier)
          .registrarse(
            nombre: _texto(_Campo.nombre),
            email: _texto(_Campo.email),
            telefono: _texto(_Campo.telefono),
            contrasenia: _texto(_Campo.contrasenia),
          );
      // Si todo va bien, las rutas llevan solas a Inicio
    } on ErrorApi catch (e) {
      if (!mounted) return;
      setState(() => _mostrarErrorApi(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarErrorApi(ErrorApi e) {
    if (e.codigo == 409) {
      _erroresServidor[_Campo.email] = e.mensaje;
      return;
    }
    if (e.errores.isEmpty) {
      _errorGeneral = e.mensaje;
      return;
    }
    for (final error in e.errores) {
      final campo = _Campo.values.asNameMap()[error.campo];
      if (campo == null || campo == _Campo.confirmacion) {
        _errorGeneral = e.mensaje;
      } else {
        _erroresServidor[campo] = error.mensaje;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaAuth(
      titulo: 'Crea tu cuenta',
      subtitulo: 'Registra tus viajes y mejora tu forma de conducir.',
      alVolver: _volverAlLogin,
      ilustracion: IlustracionEncabezado.reducida,
      tarjeta: _tarjetaFormulario(),
      pie: _pie(),
    );
  }

  Widget _tarjetaFormulario() {
    final colores = context.colores;
    final requisitos = _requisitos;
    final contraseniaTocada = _tocados.contains(_Campo.contrasenia);

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
            if (_errorGeneral != null) ...[
              AvisoError(mensaje: _errorGeneral!),
              const SizedBox(height: Espacios.m),
            ],
            _campo(
              _Campo.nombre,
              etiqueta: 'Nombre completo',
              mayusculas: TextCapitalization.words,
              autocompletado: const [AutofillHints.name],
              formateadores: [LengthLimitingTextInputFormatter(100)],
            ),
            const SizedBox(height: Espacios.m),
            _campo(
              _Campo.email,
              etiqueta: 'Correo electrónico',
              teclado: TextInputType.emailAddress,
              autocompletado: const [AutofillHints.email],
            ),
            const SizedBox(height: Espacios.m),
            _campo(
              _Campo.telefono,
              etiqueta: 'Teléfono',
              ayuda: '8 dígitos, sin código de país',
              teclado: TextInputType.number,
              autocompletado: const [AutofillHints.telephoneNumber],
              formateadores: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
            const SizedBox(height: Espacios.m),
            _campo(
              _Campo.contrasenia,
              etiqueta: 'Contraseña',
              conError: contraseniaTocada && !requisitos.cumple,
              ocultar: _ocultarContrasenia,
              alternarOcultar: () =>
                  setState(() => _ocultarContrasenia = !_ocultarContrasenia),
              autocompletado: const [AutofillHints.newPassword],
              formateadores: [LengthLimitingTextInputFormatter(128)],
              // Que el teclado no tape la lista de requisitos
              margenDesplazamiento: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              debajo: ListaRequisitosContrasenia(
                requisitos: requisitos,
                resaltarPendientes: contraseniaTocada,
              ),
            ),
            const SizedBox(height: Espacios.m),
            _campo(
              _Campo.confirmacion,
              etiqueta: 'Confirmar contraseña',
              ocultar: _ocultarConfirmacion,
              alternarOcultar: () =>
                  setState(() => _ocultarConfirmacion = !_ocultarConfirmacion),
              autocompletado: const [AutofillHints.newPassword],
              formateadores: [LengthLimitingTextInputFormatter(128)],
              accionTeclado: TextInputAction.done,
              alEnviar: (_) => _registrarse(),
            ),
            const SizedBox(height: Espacios.xl),
            BotonPrimario(
              texto: 'Crear cuenta',
              cargando: _cargando,
              alPresionar: _formularioValido ? _registrarse : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    _Campo campo, {
    required String etiqueta,
    String? ayuda,
    bool conError = false,
    bool? ocultar,
    VoidCallback? alternarOcultar,
    TextInputType? teclado,
    TextInputAction accionTeclado = TextInputAction.next,
    ValueChanged<String>? alEnviar,
    TextCapitalization mayusculas = TextCapitalization.none,
    Iterable<String>? autocompletado,
    List<TextInputFormatter>? formateadores,
    EdgeInsets margenDesplazamiento = const EdgeInsets.all(20),
    Widget? debajo,
  }) {
    return CampoFormulario(
      etiqueta: etiqueta,
      controlador: _controladores[campo]!,
      mensajeError: _mensajeVisible(campo),
      conError: conError,
      ayuda: ayuda,
      debajo: debajo,
      habilitado: !_cargando,
      ocultarTexto: ocultar ?? false,
      teclado: teclado,
      accionTeclado: accionTeclado,
      alEnviar: alEnviar,
      alCambiar: (_) => _alCambiar(campo),
      alPerderFoco: () => _alSalir(campo),
      autocompletado: autocompletado,
      formateadores: formateadores,
      mayusculas: mayusculas,
      margenDesplazamiento: margenDesplazamiento,
      sufijo: ocultar == null ? null : _botonOjo(ocultar, alternarOcultar!),
    );
  }

  Widget _botonOjo(bool oculto, VoidCallback alternar) {
    // Sin foco: si no, "Siguiente" del teclado iría al ojo en vez de al campo siguiente
    return ExcludeFocus(
      child: IconButton(
        onPressed: alternar,
        tooltip: oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(
          oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: Medidas.icono,
          color: context.colores.textoTerciario,
        ),
      ),
    );
  }

  Widget _pie() {
    final colores = context.colores;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Espacios.xxl,
        0,
        Espacios.xxl,
        MediaQuery.paddingOf(context).bottom,
      ),
      // Wrap: si no cabe (letra grande de accesibilidad), el enlace baja de línea
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '¿Ya tienes cuenta?',
            style: context.tipografia.cuerpo.copyWith(
              color: colores.textoSecundario,
            ),
          ),
          TextButton(
            onPressed: _cargando ? null : _volverAlLogin,
            child: const Text('Inicia sesión'),
          ),
        ],
      ),
    );
  }
}
