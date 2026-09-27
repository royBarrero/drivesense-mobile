import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/user.dart';

/// Respuesta de login y registro.
typedef Sesion = ({String token, Usuario usuario});

/// Llamadas a `/auth` del backend. Lanza `ErrorApi` si la petición falla.
class AuthRepositorio {
  AuthRepositorio(this._dio);

  final Dio _dio;

  /// `POST /auth/login` (solo conductores). Devuelve el token y el usuario.
  Future<Sesion> iniciarSesion({
    required String email,
    required String contrasenia,
  }) => _crearSesion('/auth/login', {
    'email': _normalizarCorreo(email),
    'contrasenia': contrasenia,
  });

  /// `POST /auth/registro`: crea un conductor individual y le inicia sesión.
  Future<Sesion> registrar({
    required String nombre,
    required String email,
    required String telefono,
    required String contrasenia,
  }) => _crearSesion('/auth/registro', {
    'nombre': nombre.trim(),
    'email': _normalizarCorreo(email),
    'telefono': telefono,
    'contrasenia': contrasenia,
  });

  // El correo siempre se envía en minúsculas y sin espacios
  String _normalizarCorreo(String email) => email.trim().toLowerCase();

  /// Login y registro responden igual: token + usuario.
  Future<Sesion> _crearSesion(String ruta, Map<String, dynamic> datos) async {
    try {
      final respuesta = await _dio.post<Map<String, dynamic>>(
        ruta,
        data: datos,
      );
      final cuerpo = respuesta.data!;
      return (
        token: cuerpo['access_token'] as String,
        usuario: Usuario.fromJson(cuerpo['usuario'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }

  /// `GET /auth/yo`: usuario del token guardado.
  Future<Usuario> obtenerUsuarioActual() async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>('/auth/yo');
      return Usuario.fromJson(respuesta.data!);
    } on DioException catch (e) {
      throw ErrorApi.desde(e);
    }
  }
}

final authRepositorioProvider = Provider<AuthRepositorio>(
  (ref) => AuthRepositorio(ref.watch(clienteApiProvider)),
);
