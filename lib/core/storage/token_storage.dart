import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT de la sesión en el almacenamiento cifrado del sistema.
class AlmacenToken {
  AlmacenToken(this._almacen);

  static const _clave = 'token_sesion';
  final FlutterSecureStorage _almacen;

  Future<String?> leer() => _almacen.read(key: _clave);

  Future<void> guardar(String token) =>
      _almacen.write(key: _clave, value: token);

  Future<void> borrar() => _almacen.delete(key: _clave);
}

final almacenTokenProvider = Provider<AlmacenToken>(
  (ref) => AlmacenToken(const FlutterSecureStorage()),
);
