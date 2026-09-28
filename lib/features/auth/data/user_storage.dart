import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// Último usuario con sesión válida, en el almacenamiento cifrado.
///
/// Permite abrir la app sin conexión (p. ej. para continuar un viaje) con el
/// token guardado. Se borra junto con el token.
class AlmacenUsuario {
  AlmacenUsuario(this._almacen);

  static const _clave = 'usuario_sesion';
  final FlutterSecureStorage _almacen;

  Future<Usuario?> leer() async {
    final texto = await _almacen.read(key: _clave);
    if (texto == null) return null;
    try {
      return Usuario.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } on Object {
      // Formato viejo o dañado
      await borrar();
      return null;
    }
  }

  Future<void> guardar(Usuario usuario) =>
      _almacen.write(key: _clave, value: jsonEncode(usuario));

  Future<void> borrar() => _almacen.delete(key: _clave);
}

final almacenUsuarioProvider = Provider<AlmacenUsuario>(
  (ref) => AlmacenUsuario(const FlutterSecureStorage()),
);
