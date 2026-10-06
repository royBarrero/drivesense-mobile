import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../recorridos/models/trip_accumulator.dart';
import '../models/calibration_mark.dart';
import '../models/sensor_sample.dart';

/// Modo calibración (solo en la versión de desarrollo): graba en un CSV todos los
/// datos crudos del viaje, sensores y GPS, con sus instantes, y las maniobras
/// marcadas a mano (filas `marca`, con su nombre en la última columna).
///
/// Un archivo por recorrido (`calibracion_<id>.csv`); al continuar un viaje
/// interrumpido se sigue escribiendo en el mismo.
class RegistroCalibracion {
  RegistroCalibracion({Future<Directory> Function()? directorio})
    : _directorio = directorio ?? getApplicationDocumentsDirectory;

  static const _encabezado =
      'tipo,fecha_us,x,y,z,lat,lon,precision_m,velocidad_ms,etiqueta\n';
  static const _escribirCada = Duration(seconds: 1);

  final Future<Directory> Function() _directorio;

  /// Líneas aún no escritas: se vuelcan al archivo cada segundo.
  final _pendiente = StringBuffer();
  Future<File>? _archivo;
  Future<void> _escritura = Future.value();
  Timer? _temporizador;
  final _marcas = <TipoMarca, int>{};

  bool get grabando => _archivo != null;

  /// Marcas de esta sesión por tipo (al continuar un viaje interrumpido, las
  /// anteriores siguen en el CSV pero no se cuentan).
  int marcas(TipoMarca tipo) => _marcas[tipo] ?? 0;

  /// Empieza a grabar el recorrido. Si es un viaje [nuevo], borra los CSV de
  /// viajes anteriores.
  void iniciar(int recorridoId, {required bool nuevo}) {
    if (grabando) return;
    _marcas.clear();
    _archivo = _preparar(recorridoId, nuevo: nuevo);
    _temporizador = Timer.periodic(_escribirCada, (_) => _volcar());
  }

  void sensor(TipoSensor tipo, MuestraSensor m) {
    if (!grabando) return;
    final codigo = tipo == TipoSensor.acelerometro ? 'acc' : 'gir';
    _pendiente.write(
      '$codigo,${m.fecha.microsecondsSinceEpoch},${m.x},${m.y},${m.z},,,,,\n',
    );
  }

  /// Toda lectura del GPS, también las que el acumulador descarta.
  void gps(Lectura l) {
    if (!grabando) return;
    _pendiente.write(
      'gps,${l.fecha.microsecondsSinceEpoch},,,,${l.latitud},${l.longitud},'
      '${l.precisionM},${l.velocidadMs},\n',
    );
  }

  /// Maniobra marcada a mano en el instante [fecha].
  void marca(TipoMarca tipo, DateTime fecha) {
    if (!grabando) return;
    _pendiente.write(
      'marca,${fecha.microsecondsSinceEpoch},,,,,,,,${tipo.etiqueta}\n',
    );
    _marcas[tipo] = marcas(tipo) + 1;
  }

  /// Deja de grabar y devuelve el archivo (o `null` si no estaba grabando).
  Future<File?> detener() async {
    final archivo = _archivo;
    if (archivo == null) return null;
    _temporizador?.cancel();
    _temporizador = null;
    _volcar();
    _archivo = null;
    await _escritura;
    return archivo;
  }

  /// CSV ya grabado de un recorrido (p. ej. al finalizar un viaje interrumpido).
  Future<File?> archivoDe(int recorridoId) async {
    // Las últimas líneas pueden estar escribiéndose aún
    await _escritura;
    final directorio = await _directorio();
    final archivo = File('${directorio.path}/${_nombre(recorridoId)}');
    return await archivo.exists() ? archivo : null;
  }

  String _nombre(int recorridoId) => 'calibracion_$recorridoId.csv';

  Future<File> _preparar(int recorridoId, {required bool nuevo}) async {
    final directorio = await _directorio();
    final nombre = _nombre(recorridoId);
    if (nuevo) {
      await for (final entrada in directorio.list()) {
        final base = entrada.uri.pathSegments.last;
        if (entrada is File &&
            base.startsWith('calibracion_') &&
            base.endsWith('.csv') &&
            base != nombre) {
          await entrada.delete();
        }
      }
    }
    final archivo = File('${directorio.path}/$nombre');
    if (!await archivo.exists()) {
      await archivo.writeAsString(_encabezado, flush: true);
    }
    return archivo;
  }

  /// Escrituras en serie, para que las líneas no se desordenen.
  void _volcar() {
    final archivo = _archivo;
    if (archivo == null || _pendiente.isEmpty) return;
    final texto = _pendiente.toString();
    _pendiente.clear();
    _escritura = _escritura.then(
      (_) async => (await archivo).writeAsString(texto, mode: FileMode.append),
    );
  }
}

final registroCalibracionProvider = Provider<RegistroCalibracion>(
  (ref) => RegistroCalibracion(),
);
