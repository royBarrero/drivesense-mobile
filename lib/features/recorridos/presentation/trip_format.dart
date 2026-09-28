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

  /// Kilómetros con 2 decimales: `1,25`.
  static String kilometros(double metros) =>
      (metros / 1000).toStringAsFixed(2).replaceAll('.', ',');

  /// Velocidad sin decimales: `48`.
  static String velocidad(double kmh) => kmh.round().toString();

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
