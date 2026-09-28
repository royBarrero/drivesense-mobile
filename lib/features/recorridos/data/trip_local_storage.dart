import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

/// Guarda en el teléfono el viaje en curso y el resumen pendiente de envío.
///
/// Las claves llevan el id del usuario: otra cuenta en el mismo teléfono no los hereda,
/// y si se cierra sesión se conservan hasta que esa cuenta vuelva a entrar.
class AlmacenRecorrido {
  AlmacenRecorrido(this._preferencias);

  final SharedPreferencesAsync _preferencias;

  String _claveViaje(int usuarioId) => 'recorrido_activo_$usuarioId';
  String _claveResumen(int usuarioId) => 'resumen_pendiente_$usuarioId';

  Future<ViajeActivo?> leerViaje(int usuarioId) =>
      _leer(_claveViaje(usuarioId), ViajeActivo.fromJson);

  Future<void> guardarViaje(int usuarioId, ViajeActivo viaje) =>
      _preferencias.setString(_claveViaje(usuarioId), jsonEncode(viaje));

  Future<void> borrarViaje(int usuarioId) =>
      _preferencias.remove(_claveViaje(usuarioId));

  Future<ResumenRecorrido?> leerResumen(int usuarioId) =>
      _leer(_claveResumen(usuarioId), ResumenRecorrido.fromJson);

  Future<void> guardarResumen(int usuarioId, ResumenRecorrido resumen) =>
      _preferencias.setString(_claveResumen(usuarioId), jsonEncode(resumen));

  Future<void> borrarResumen(int usuarioId) =>
      _preferencias.remove(_claveResumen(usuarioId));

  Future<T?> _leer<T>(
    String clave,
    T Function(Map<String, dynamic> json) desdeJson,
  ) async {
    final texto = await _preferencias.getString(clave);
    if (texto == null) return null;
    try {
      return desdeJson(jsonDecode(texto) as Map<String, dynamic>);
    } on Object {
      // Formato viejo o dañado: se descarta
      await _preferencias.remove(clave);
      return null;
    }
  }
}

final almacenRecorridoProvider = Provider<AlmacenRecorrido>(
  (ref) => AlmacenRecorrido(SharedPreferencesAsync()),
);
