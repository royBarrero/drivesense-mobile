/// Validaciones del registro de conductor (HU-01). Devuelven el mensaje de error
/// o `null` si el valor es válido. Replican las reglas del backend.
library;

final _formatoCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _telefono = RegExp(r'^\d{8}$');
// Igual que el backend: solo letras sin tilde cuentan como "letra"
final _letra = RegExp(r'[A-Za-z]');
final _numero = RegExp(r'\d');

String? validarNombre(String nombre) =>
    nombre.trim().isEmpty ? 'Ingresa tu nombre' : null;

String? validarCorreo(String correo) =>
    _formatoCorreo.hasMatch(correo.trim()) ? null : 'Ingresa un correo válido';

/// Celular boliviano: 8 dígitos. Mismo mensaje que la API.
String? validarTelefono(String telefono) =>
    _telefono.hasMatch(telefono) ? null : 'El teléfono debe tener 8 dígitos';

String? validarConfirmacion(String contrasenia, String confirmacion) {
  if (confirmacion.isEmpty) return 'Confirma tu contraseña';
  if (confirmacion != contrasenia) return 'Las contraseñas no coinciden';
  return null;
}

/// Estado de cada requisito de la contraseña.
class RequisitosContrasenia {
  RequisitosContrasenia(String contrasenia)
    : largo = contrasenia.length >= 8,
      letra = _letra.hasMatch(contrasenia),
      numero = _numero.hasMatch(contrasenia);

  final bool largo;
  final bool letra;
  final bool numero;

  bool get cumple => largo && letra && numero;
}
