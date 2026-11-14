import 'package:dio/dio.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/gamificacion/data/gamification_repository.dart';
import 'package:drivesense/features/gamificacion/models/progress.dart';
import 'package:drivesense/features/gamificacion/models/weekly_challenges.dart';
import 'package:drivesense/features/gamificacion/presentation/challenges_screen.dart';
import 'package:drivesense/features/gamificacion/providers/challenges_provider.dart';
import 'package:drivesense/features/puntaje/data/score_repository.dart';
import 'package:drivesense/features/recorridos/models/trip_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _usuario = Usuario(
  id: 1,
  nombre: 'Ana Pérez',
  email: 'ana@prueba.com',
  telefono: '70000001',
  rol: 'conductor',
  debeCambiarContrasenia: false,
);

class _SesionFija extends SesionNotifier {
  @override
  Future<Usuario?> build() async => _usuario;
}

/// Repositorio sin red: guarda el `desde` que recibe.
class _GamificacionFalsa extends GamificacionRepositorio {
  _GamificacionFalsa(this.respuesta) : super(Dio());

  Future<Map<String, dynamic>> Function() respuesta;
  final desdes = <DateTime>[];

  @override
  Future<DesafiosSemana> desafios({required DateTime desde}) async {
    desdes.add(desde);
    return DesafiosSemana.fromJson(await respuesta());
  }
}

Map<String, dynamic> _desafio(
  String codigo,
  String nombre, {
  String tipo = 'constancia',
  String tipoProgreso = 'viajes',
  int meta = 5,
  int progreso = 0,
  bool completado = false,
  int puntos = 150,
  String? categoria,
  int? promedio,
  int? viajes,
  int? viajesMinimos,
}) => {
  'codigo': codigo,
  'tipo': tipo,
  'nombre': nombre,
  'descripcion': 'Descripción de $nombre.',
  'tipo_progreso': tipoProgreso,
  'meta': meta,
  'progreso': progreso,
  'completado': completado,
  'puntos': puntos,
  'categoria': categoria,
  'promedio': promedio,
  'viajes': viajes,
  'viajes_minimos': viajesMinimos,
};

Map<String, dynamic> _semana({bool bonoRecibido = false}) => {
  'inicio': '2026-11-09T05:00:00Z',
  'fin': '2026-11-16T05:00:00Z',
  'bono': {'puntos': 100, 'recibido': bonoRecibido},
  'desafios': [
    _desafio(
      'kilometros_seguros',
      'Kilómetros seguros',
      tipoProgreso: 'km',
      meta: 50,
      progreso: 34,
    ),
    _desafio(
      'promedio_muy_bueno',
      'Promedio muy bueno',
      tipo: 'calidad',
      tipoProgreso: 'promedio',
      meta: 80,
      progreso: 80,
      completado: true,
      puntos: 200,
      promedio: 98,
      viajes: 3,
      viajesMinimos: 3,
    ),
    _desafio(
      'sin_giros_agresivos',
      'Sin giros agresivos',
      tipo: 'punto_debil',
      meta: 3,
      progreso: 1,
      puntos: 200,
      categoria: 'giros',
    ),
  ],
};

Desafio _de(Map<String, dynamic> json) => Desafio.fromJson(json);

Future<_GamificacionFalsa> _mostrar(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function()? respuesta,
}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final repositorio = _GamificacionFalsa(respuesta ?? () async => _semana());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        gamificacionRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp(
        theme: temaClaro(),
        home: DesafiosPantalla(
          reloj: () => DateTime.utc(2026, 11, 13, 17).toLocal(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  group('Modelo', () {
    test('lee la semana y los tipos', () {
      final semana = DesafiosSemana.fromJson(_semana());
      expect(semana.desafios, hasLength(3));
      expect(semana.completados, 1);
      expect(semana.fin, DateTime.utc(2026, 11, 16, 5).toLocal());
      final [constancia, calidad, debil] = semana.desafios;
      expect(constancia.tipo, TipoDesafio.constancia);
      expect(constancia.tipoProgreso, TipoProgreso.km);
      expect(calidad.tipo, TipoDesafio.calidad);
      expect(calidad.tipoProgreso, TipoProgreso.promedio);
      expect(debil.tipo, TipoDesafio.puntoDebil);
      expect(debil.categoria, CategoriaPuntaje.giros);
      expect(constancia.categoria, isNull);
    });

    test('textos de avance', () {
      expect(_de(_desafio('a', 'A', progreso: 2)).avanceTexto, '2 de 5 viajes');
      expect(
        _de(_desafio('a', 'A', tipoProgreso: 'viaje', meta: 1)).avanceTexto,
        '0 de 1 viaje',
      );
      expect(
        _de(
          _desafio('a', 'A', tipoProgreso: 'km', meta: 50, progreso: 34),
        ).avanceTexto,
        '34 de 50 km',
      );
      expect(
        _de(
          _desafio('a', 'A', tipoProgreso: 'racha', meta: 3, progreso: 1),
        ).avanceTexto,
        'Racha actual: 1 de 3',
      );
    });

    test('promedio: viajes que faltan y luego el promedio', () {
      Desafio promedio({int? valor, int viajes = 0}) => _de(
        _desafio(
          'promedio_muy_bueno',
          'P',
          tipoProgreso: 'promedio',
          meta: 80,
          progreso: (valor ?? 0).clamp(0, 80),
          promedio: valor,
          viajes: viajes,
          viajesMinimos: 3,
        ),
      );
      expect(promedio().avanceTexto, '0 de 3 viajes');
      expect(promedio().avance, 0);
      final dos = promedio(valor: 90, viajes: 2);
      expect(dos.avanceTexto, 'Promedio 90 · 2 de 3 viajes');
      expect(dos.avance, closeTo(2 / 3, 0.001));
      final cuatro = promedio(valor: 76, viajes: 4);
      expect(cuatro.avanceTexto, 'Promedio 76 · meta 80');
      expect(cuatro.avance, closeTo(0.95, 0.001));
    });

    test('avance: completado llena la barra', () {
      expect(_de(_desafio('a', 'A', progreso: 2)).avance, closeTo(0.4, 0.001));
      expect(_de(_desafio('a', 'A', progreso: 5, completado: true)).avance, 1);
    });

    test('tiempo restante', () {
      final semana = DesafiosSemana(
        inicio: DateTime(2026, 11, 9),
        fin: DateTime(2026, 11, 16),
        desafios: const [],
      );
      expect(
        semana.tiempoRestante(DateTime(2026, 11, 13, 14)),
        'Quedan 2 días',
      );
      expect(semana.tiempoRestante(DateTime(2026, 11, 14, 22)), 'Queda 1 día');
      expect(semana.tiempoRestante(DateTime(2026, 11, 15, 19)), 'Quedan 5 h');
      expect(
        semana.tiempoRestante(DateTime(2026, 11, 15, 23, 30)),
        'Queda menos de 1 h',
      );
      expect(
        semana.tiempoRestante(DateTime(2026, 11, 16)),
        'La semana terminó',
      );
    });

    test('bono: lo lee y, sin la clave, 100 pts sin recibir', () {
      final con = DesafiosSemana.fromJson(_semana(bonoRecibido: true));
      expect((con.bono.puntos, con.bono.recibido), (100, true));
      final json = _semana()..remove('bono');
      final sin = DesafiosSemana.fromJson(json);
      expect((sin.bono.puntos, sin.bono.recibido), (100, false));
    });

    test('desde va con la zona del teléfono', () {
      final lunes = DateTime(2026, 11, 9);
      expect(isoConZona(lunes), startsWith('2026-11-09T00:00:00'));
    });
  });

  group('Pantalla', () {
    testWidgets('resumen, tiempo restante y cada desafío con su avance', (
      tester,
    ) async {
      final repositorio = await _mostrar(tester);

      // Pide la semana desde el lunes 00:00 local
      final desde = repositorio.desdes.single;
      expect(
        (desde.weekday, desde.hour, desde.minute),
        (DateTime.monday, 0, 0),
      );

      expect(find.text('Desafíos semanales'), findsOneWidget);
      expect(find.text('de 3 completados'), findsOneWidget);
      expect(find.textContaining('Queda'), findsOneWidget);

      expect(find.text('CONSTANCIA'), findsOneWidget);
      expect(find.text('CALIDAD'), findsOneWidget);
      expect(find.text('TU PUNTO DÉBIL'), findsOneWidget);
      expect(find.text('Kilómetros seguros'), findsOneWidget);
      expect(find.text('Descripción de Kilómetros seguros.'), findsOneWidget);
      expect(find.text('34 de 50 km'), findsOneWidget);
      expect(find.text('+150 pts'), findsOneWidget);
      // Solo el punto débil sigue ofreciendo sus 200 pts
      expect(find.text('+200 pts'), findsOneWidget);
      expect(find.text('1 de 3 viajes'), findsOneWidget);
      // El promedio está completado: muestra los puntos recibidos, no el avance
      expect(find.text('Completado'), findsOneWidget);
      expect(find.text('+200 pts recibidos'), findsOneWidget);
      expect(find.text('Promedio 98 · meta 80'), findsNothing);
      // Bono por completar los 3, todavía sin recibir
      expect(
        find.text('Completa los 3 y gana +100 pts de bono'),
        findsOneWidget,
      );
      // El punto débil usa el ícono del giro
      expect(find.byIcon(Icons.turn_right), findsOneWidget);
    });

    testWidgets('bono recibido', (tester) async {
      await _mostrar(
        tester,
        respuesta: () async => _semana(bonoRecibido: true),
      );
      expect(find.text('Bono recibido · +100 pts'), findsOneWidget);
      expect(find.textContaining('Completa los 3'), findsNothing);
    });

    testWidgets('error: reintentar', (tester) async {
      var falla = true;
      await _mostrar(
        tester,
        respuesta: () async {
          if (falla) throw const ErrorApi(mensaje: 'Sin conexión');
          return _semana();
        },
      );
      expect(find.text('Sin conexión'), findsOneWidget);

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Kilómetros seguros'), findsOneWidget);
    });
  });

  test('desafiosProvider es nulo sin sesión', () async {
    final contenedor = ProviderContainer(
      overrides: [sesionProvider.overrideWith(_SinSesion.new)],
    );
    addTearDown(contenedor.dispose);
    expect(await contenedor.read(desafiosProvider.future), isNull);
  });
}

class _SinSesion extends SesionNotifier {
  @override
  Future<Usuario?> build() async => null;
}
