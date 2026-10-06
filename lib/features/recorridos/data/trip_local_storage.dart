import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telemetria/models/route.dart';
import '../models/trip.dart';

/// Guarda en el teléfono el viaje en curso y el resumen pendiente de envío.
///
/// Las claves llevan el id del usuario: otra cuenta en el mismo teléfono no los hereda,
/// y si se cierra sesión se conservan hasta que esa cuenta vuelva a entrar.
///
/// La ruta del viaje en curso va en un archivo aparte (`ruta_<usuario>.jsonl`, un
/// punto por línea) al que solo se agregan los puntos nuevos: puede pesar cientos
/// de KB y no conviene reescribirla entera cada 5 s. El resumen pendiente, que se
/// escribe una sola vez, lleva la ruta dentro.
class AlmacenRecorrido {
  AlmacenRecorrido(
    this._preferencias, {
    Future<Directory> Function()? directorio,
  }) : _directorio = directorio ?? getApplicationDocumentsDirectory;

  final SharedPreferencesAsync _preferencias;
  final Future<Directory> Function() _directorio;

  /// Operaciones sobre el archivo de ruta, en serie (se guarda cada 5 s sin esperar).
  Future<void> _operacionRuta = Future.value();

  String _claveViaje(int usuarioId) => 'recorrido_activo_$usuarioId';
  String _claveResumen(int usuarioId) => 'resumen_pendiente_$usuarioId';

  Future<File> _archivoRuta(int usuarioId) async =>
      File('${(await _directorio()).path}/ruta_$usuarioId.jsonl');

  Future<ViajeActivo?> leerViaje(int usuarioId) async {
    final ruta = await _enSerie(() => _leerRuta(usuarioId));
    return _leer(
      _claveViaje(usuarioId),
      (json) => ViajeActivo.fromJson(json, ruta: ruta),
    );
  }

  /// Guarda los acumulados y agrega a la ruta los puntos nuevos.
  Future<void> guardarViaje(int usuarioId, ViajeActivo viaje) async {
    // Se toman ya: el viaje sigue sumando puntos mientras se escribe
    final (:completa, :puntos) = viaje.ruta.tomarSinGuardar();
    await _preferencias.setString(_claveViaje(usuarioId), jsonEncode(viaje));
    if (!completa && puntos.isEmpty) return;
    await _enSerie(() async {
      final texto = puntos.map((p) => '${jsonEncode(p)}\n').join();
      await (await _archivoRuta(usuarioId)).writeAsString(
        texto,
        mode: completa ? FileMode.write : FileMode.append,
      );
    });
  }

  Future<void> borrarViaje(int usuarioId) async {
    await _preferencias.remove(_claveViaje(usuarioId));
    await _enSerie(() async {
      final archivo = await _archivoRuta(usuarioId);
      if (await archivo.exists()) await archivo.delete();
    });
  }

  Future<List<PuntoRuta>> _leerRuta(int usuarioId) async {
    final archivo = await _archivoRuta(usuarioId);
    if (!await archivo.exists()) return const [];
    final puntos = <PuntoRuta>[];
    for (final linea in await archivo.readAsLines()) {
      try {
        puntos.add(
          PuntoRuta.fromJson(jsonDecode(linea) as Map<String, dynamic>),
        );
      } on Object {
        // Línea cortada (la app se cerró mientras escribía): se omite
      }
    }
    return puntos;
  }

  Future<T> _enSerie<T>(Future<T> Function() operacion) {
    final resultado = _operacionRuta.then((_) => operacion());
    _operacionRuta = resultado.then((_) {}, onError: (Object _) {});
    return resultado;
  }

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
