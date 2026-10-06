import '../../telemetria/models/event_detector.dart';

/// Formato de las métricas del viaje (coma decimal, como el resto de la interfaz).
abstract final class FormatoViaje {
  /// `hh:mm:ss`, o `mm:ss` si no llega a una hora.
  static String duracion(int segundos) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final horas = segundos ~/ 3600;
    final minutos = segundos % 3600 ~/ 60;
    final resto = segundos % 60;
    return horas > 0
        ? '${dos(horas)}:${dos(minutos)}:${dos(resto)}'
        : '${dos(minutos)}:${dos(resto)}';
  }

  /// `m:ss` (`0:12`, `1:15`): tiempo sobre el límite de velocidad.
  static String minutosSegundos(int segundos) =>
      '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';

  /// Kilómetros con 2 decimales por debajo de 10 km (`7,42`) y 1 desde ahí (`16,2`).
  static String kilometros(double metros) {
    final km = metros / 1000;
    // 9,996 km redondea a 10,00: desde ahí ya va con un decimal
    final decimales = km < 9.995 ? 2 : 1;
    return km.toStringAsFixed(decimales).replaceAll('.', ',');
  }

  /// Kilómetros para una tarjeta pequeña (Inicio): enteros (`42`) y, bajo
  /// 10 km, con un decimal (`4,3`); sin distancia, `0`.
  static String kilometrosEnteros(double metros) {
    final km = metros / 1000;
    if (metros <= 0) return '0';
    // 9,96 km redondea a 10,0: desde ahí ya va sin decimales
    return km < 9.95
        ? km.toStringAsFixed(1).replaceAll('.', ',')
        : km.round().toString();
  }

  /// Horas y minutos compactos (Inicio): `32m`, `1h 25m`, `2h 5m`.
  static String duracionCompacta(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = segundos % 3600 ~/ 60;
    return horas > 0 ? '${horas}h ${minutos}m' : '${minutos}m';
  }

  /// Velocidad sin decimales: `48`.
  static String velocidad(double kmh) => kmh.round().toString();

  /// Horas y minutos: `18 min`, `1 h 05 min`.
  static String duracionCorta(int segundos) => [
    for (final (valor, unidad) in duracionPartes(segundos)) '$valor $unidad',
  ].join(' ');

  /// Partes de [duracionCorta] (valor, unidad), para mostrar el número más grande.
  static List<(String, String)> duracionPartes(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = segundos % 3600 ~/ 60;
    return horas > 0
        ? [('$horas', 'h'), (_dos(minutos), 'min')]
        : [('$minutos', 'min')];
  }

  /// `18:30`, en la zona horaria del teléfono.
  static String hora(DateTime fecha) {
    final local = fecha.toLocal();
    return '${_dos(local.hour)}:${_dos(local.minute)}';
  }

  /// `Hoy`, `Ayer` o `domingo 27 de septiembre`, en la zona del teléfono.
  static String dia(DateTime fecha, {DateTime? ahora}) {
    final local = fecha.toLocal();
    final hoy = _soloDia((ahora ?? DateTime.now()).toLocal());
    final diferencia = hoy.difference(_soloDia(local)).inHours;
    // Por horas y redondeado: un día con cambio de horario dura 23 o 25 h
    return switch ((diferencia / 24).round()) {
      0 => 'Hoy',
      1 => 'Ayer',
      _ => fechaLarga(local),
    };
  }

  /// `Hoy`, `Ayer` o `27 sep`: para una línea corta (último viaje de Inicio).
  static String diaCorto(DateTime fecha, {DateTime? ahora}) {
    final nombre = dia(fecha, ahora: ahora);
    return nombre == 'Hoy' || nombre == 'Ayer' ? nombre : fechaCorta(fecha);
  }

  /// `Hoy · domingo 27 de septiembre`; si no es hoy ni ayer, `Martes 1 de septiembre`.
  static String fechaDetalle(DateTime fecha, {DateTime? ahora}) {
    final nombre = dia(fecha, ahora: ahora);
    final larga = fechaLarga(fecha.toLocal());
    return nombre == larga
        ? '${larga[0].toUpperCase()}${larga.substring(1)}'
        : '$nombre · $larga';
  }

  /// `domingo 27 de septiembre`.
  static String fechaLarga(DateTime fecha) =>
      '${_dias[fecha.weekday - 1]} ${fecha.day} de ${_meses[fecha.month - 1]}';

  /// `28 sep`, en la zona del teléfono.
  static String fechaCorta(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.day} ${_meses[local.month - 1].substring(0, 3)}';
  }

  static DateTime _soloDia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  static String _dos(int n) => n.toString().padLeft(2, '0');

  static const _dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// `Hoy · 16:05 – 16:23` (o `26/09 · …`); el inicio es la llegada menos la duración.
  static String franjaHoraria(DateTime fin, int duracionS, {DateTime? ahora}) {
    String dos(int n) => n.toString().padLeft(2, '0');
    String hora(DateTime f) => '${dos(f.hour)}:${dos(f.minute)}';
    final llegada = fin.toLocal();
    final salida = llegada.subtract(Duration(seconds: duracionS));
    final hoy = (ahora ?? DateTime.now()).toLocal();
    final esHoy =
        salida.year == hoy.year &&
        salida.month == hoy.month &&
        salida.day == hoy.day;
    final dia = esHoy ? 'Hoy' : '${dos(salida.day)}/${dos(salida.month)}';
    return '$dia · ${hora(salida)} – ${hora(llegada)}';
  }
}

/// Texto de un evento de riesgo en el mapa del viaje (HU-29).
abstract final class FormatoEvento {
  /// Lo medido y la velocidad: `3,4 m/s² · a 38 km/h` (frenada y giro),
  /// `2,8 m/s² · desde 10 km/h` (aceleración) o `9 s · máx. 68 km/h` (exceso;
  /// desde un minuto, `1:15 · máx. 68 km/h`).
  static String detalle(EventoRiesgo evento) {
    final velocidad = FormatoViaje.velocidad(evento.velocidadPreviaMs * 3.6);
    final intensidad =
        '${evento.intensidad.toStringAsFixed(1).replaceAll('.', ',')} m/s²';
    return switch (evento.tipo) {
      TipoEvento.frenadaBrusca ||
      TipoEvento.giroAgresivo => '$intensidad · a $velocidad km/h',
      TipoEvento.aceleracionSevera => '$intensidad · desde $velocidad km/h',
      TipoEvento.excesoVelocidad => () {
        final segundos = (evento.duracionS ?? 0).floor();
        final maxima = FormatoViaje.velocidad(
          (evento.velocidadMaximaMs ?? evento.velocidadPreviaMs) * 3.6,
        );
        final duracion = segundos < 60
            ? '$segundos s'
            : FormatoViaje.minutosSegundos(segundos);
        return '$duracion · máx. $maxima km/h';
      }(),
    };
  }
}
