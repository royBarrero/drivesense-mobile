import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Teléfono y versión de la app que registran el viaje: se envían al iniciarlo
/// para comparar la detección entre teléfonos. Se leen una sola vez.
abstract final class DatosDispositivo {
  static Future<Map<String, String>>? _datos;

  /// `dispositivo_modelo`, `dispositivo_android` y `version_app` para el
  /// `POST /recorridos`. Si algo falla, se omite: no debe impedir el viaje.
  static Future<Map<String, String>> leer() => _datos ??= _leer();

  static Future<Map<String, String>> _leer() async {
    final datos = <String, String>{};
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      datos['dispositivo_modelo'] = _recortar(
        '${android.manufacturer} ${android.model}',
        100,
      );
      datos['dispositivo_android'] = _recortar(android.version.release, 20);
    } catch (e) {
      debugPrint('No se pudo leer el dispositivo: $e');
    }
    try {
      final paquete = await PackageInfo.fromPlatform();
      datos['version_app'] = _recortar(paquete.version, 20);
    } catch (e) {
      debugPrint('No se pudo leer la versión de la app: $e');
    }
    // El backend rechaza textos vacíos
    datos.removeWhere((_, valor) => valor.isEmpty);
    return datos;
  }

  static String _recortar(String texto, int largo) {
    final limpio = texto.trim();
    return limpio.length <= largo ? limpio : limpio.substring(0, largo);
  }
}
