/// Datos básicos de la empresa del usuario (nulos para el conductor individual).
class EmpresaResumen {
  const EmpresaResumen({
    required this.id,
    required this.nombre,
    required this.tipo,
  });

  factory EmpresaResumen.fromJson(Map<String, dynamic> json) => EmpresaResumen(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    tipo: json['tipo'] as String,
  );

  final int id;
  final String nombre;

  /// `flota` | `aseguradora`
  final String tipo;

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'tipo': tipo};
}

/// Usuario autenticado, tal como lo devuelve `UsuarioSalida` del backend.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    required this.debeCambiarContrasenia,
    this.empresa,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    telefono: json['telefono'] as String,
    rol: json['rol'] as String,
    debeCambiarContrasenia: json['debe_cambiar_contrasenia'] as bool,
    empresa: json['empresa'] == null
        ? null
        : EmpresaResumen.fromJson(json['empresa'] as Map<String, dynamic>),
  );

  final int id;
  final String nombre;
  final String email;
  final String telefono;

  /// `conductor` | `admin_empresa`
  final String rol;
  final bool debeCambiarContrasenia;
  final EmpresaResumen? empresa;

  /// Mismo formato que `fromJson` (se guarda en el teléfono para entrar sin conexión).
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'telefono': telefono,
    'rol': rol,
    'debe_cambiar_contrasenia': debeCambiarContrasenia,
    'empresa': empresa?.toJson(),
  };
}
