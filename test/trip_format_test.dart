import 'package:drivesense/features/recorridos/models/trip_history.dart';
import 'package:drivesense/features/recorridos/presentation/trip_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatoViaje', () {
    test('kilómetros: 2 decimales bajo 10 km y 1 desde ahí', () {
      expect(FormatoViaje.kilometros(7400), '7,40');
      expect(FormatoViaje.kilometros(9994), '9,99');
      // 9,996 redondearía a "10,00"
      expect(FormatoViaje.kilometros(9996), '10,0');
      expect(FormatoViaje.kilometros(16240), '16,2');
      expect(FormatoViaje.kilometros(142000), '142,0');
    });

    test('kilómetros y duración compactos de Inicio', () {
      expect(FormatoViaje.kilometrosEnteros(0), '0');
      expect(FormatoViaje.kilometrosEnteros(4280), '4,3');
      expect(FormatoViaje.kilometrosEnteros(9940), '9,9');
      // 9,96 redondearía a "10,0"
      expect(FormatoViaje.kilometrosEnteros(9960), '10');
      expect(FormatoViaje.kilometrosEnteros(42400), '42');
      expect(FormatoViaje.duracionCompacta(0), '0m');
      expect(FormatoViaje.duracionCompacta(1940), '32m');
      expect(FormatoViaje.duracionCompacta(5100), '1h 25m');
      expect(FormatoViaje.duracionCompacta(7500), '2h 5m');
    });

    test('duración en horas y minutos', () {
      expect(FormatoViaje.duracionCorta(1112), '18 min');
      expect(FormatoViaje.duracionCorta(3900), '1 h 05 min');
      expect(FormatoViaje.duracionCorta(13200), '3 h 40 min');
      expect(FormatoViaje.duracionPartes(13200), [('3', 'h'), ('40', 'min')]);
    });

    test('día corto: hoy, ayer o la fecha corta', () {
      final ahora = DateTime(2026, 10, 4, 20);
      expect(
        FormatoViaje.diaCorto(DateTime(2026, 10, 4, 8), ahora: ahora),
        'Hoy',
      );
      expect(
        FormatoViaje.diaCorto(DateTime(2026, 10, 3, 8), ahora: ahora),
        'Ayer',
      );
      expect(
        FormatoViaje.diaCorto(DateTime(2026, 10, 1, 17), ahora: ahora),
        '1 oct',
      );
    });

    test('hora y día en la zona del teléfono', () {
      final ahora = DateTime(2026, 9, 27, 20);
      expect(FormatoViaje.hora(DateTime(2026, 9, 27, 8, 5)), '08:05');
      expect(
        FormatoViaje.dia(DateTime(2026, 9, 27, 0, 1), ahora: ahora),
        'Hoy',
      );
      expect(FormatoViaje.dia(DateTime(2026, 9, 26, 23), ahora: ahora), 'Ayer');
      expect(
        FormatoViaje.dia(DateTime(2026, 9, 25, 10), ahora: ahora),
        'viernes 25 de septiembre',
      );
      expect(
        FormatoViaje.fechaDetalle(DateTime(2026, 9, 27, 18), ahora: ahora),
        'Hoy · domingo 27 de septiembre',
      );
      expect(
        FormatoViaje.fechaDetalle(DateTime(2026, 9, 1, 18), ahora: ahora),
        'Martes 1 de septiembre',
      );
    });
  });

  group('PeriodoHistorial.desde', () {
    test('esta semana empieza el lunes a medianoche', () {
      // Domingo 27 → lunes 21
      expect(
        PeriodoHistorial.semana.desde(DateTime(2026, 9, 27, 20)),
        DateTime(2026, 9, 21),
      );
      // Un lunes es su propio inicio de semana
      expect(
        PeriodoHistorial.semana.desde(DateTime(2026, 9, 21, 0, 5)),
        DateTime(2026, 9, 21),
      );
      // Cruza el mes: jueves 1 de octubre → lunes 28 de septiembre
      expect(
        PeriodoHistorial.semana.desde(DateTime(2026, 10, 1, 9)),
        DateTime(2026, 9, 28),
      );
    });

    test('este mes empieza el día 1 y todos no filtra', () {
      expect(
        PeriodoHistorial.mes.desde(DateTime(2026, 9, 27, 20)),
        DateTime(2026, 9),
      );
      expect(PeriodoHistorial.todos.desde(DateTime(2026, 9, 27)), isNull);
    });
  });
}
