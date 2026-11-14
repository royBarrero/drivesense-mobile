import 'package:dio/dio.dart';
import 'package:drivesense/app/router.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/gamificacion/data/gamification_repository.dart';
import 'package:drivesense/features/gamificacion/models/progress.dart';
import 'package:drivesense/features/gamificacion/presentation/achievements_screen.dart';
import 'package:drivesense/features/gamificacion/presentation/widgets/level_card.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

/// Repositorio sin red.
class _GamificacionFalsa extends GamificacionRepositorio {
  _GamificacionFalsa(this.respuesta) : super(Dio());

  Map<String, dynamic> Function() respuesta;
  int pedidos = 0;

  @override
  Future<ProgresoConductor> progreso() async {
    pedidos++;
    return ProgresoConductor.fromJson(respuesta());
  }
}

Map<String, dynamic> _logro(
  String codigo,
  String nombre, {
  String tipo = 'viajes',
  int meta = 1,
  int progreso = 0,
  String? fecha,
}) => {
  'codigo': codigo,
  'nombre': nombre,
  'descripcion': 'Descripción de $nombre.',
  'tipo': tipo,
  'meta': meta,
  'progreso': fecha == null ? progreso : meta,
  'desbloqueado': fecha != null,
  'fecha_desbloqueo': fecha,
};

Map<String, dynamic> _progreso({
  int puntos = 240,
  Map<String, dynamic>? nivel,
  Map<String, dynamic>? siguiente = const {
    'numero': 4,
    'nombre': 'Conductor seguro',
    'puntos': 600,
  },
}) => {
  'puntos': puntos,
  'nivel': nivel ?? {'numero': 3, 'nombre': 'Conductor', 'puntos': 300},
  'siguiente_nivel': siguiente,
  'logros': [
    _logro('primer_viaje', 'Primer viaje', fecha: '2026-11-03T15:00:00Z'),
    _logro(
      'viaje_limpio',
      'Viaje limpio',
      tipo: 'viaje',
      fecha: '2026-11-05T15:00:00Z',
    ),
    _logro('puntaje_excelente', 'Puntaje excelente', tipo: 'viaje'),
    _logro('buena_racha', 'Buena racha', tipo: 'racha', meta: 5, progreso: 3),
    _logro('constante', 'Constante', meta: 10, progreso: 7),
    _logro(
      'cien_kilometros',
      'Cien kilómetros',
      tipo: 'km',
      meta: 100,
      progreso: 63,
    ),
  ],
};

Future<_GamificacionFalsa> _mostrar(
  WidgetTester tester,
  Map<String, dynamic> Function() respuesta, {
  String inicial = Rutas.perfil,
}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final repositorio = _GamificacionFalsa(respuesta);
  final router = GoRouter(
    initialLocation: inicial,
    routes: [
      GoRoute(
        path: Rutas.perfil,
        builder: (_, _) => const Scaffold(body: TarjetaNivel()),
        routes: [
          GoRoute(path: 'logros', builder: (_, _) => const LogrosPantalla()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        gamificacionRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp.router(theme: temaClaro(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  group('Modelo', () {
    test('lee el progreso', () {
      final p = ProgresoConductor.fromJson(_progreso());
      expect(p.nivel.nombre, 'Conductor');
      expect(p.siguienteNivel!.puntos, 600);
      expect(p.desbloqueados, 2);
      expect(p.logros.first.fechaDesbloqueo, isNotNull);
      // 240 está por debajo del mínimo del nivel 3 (300): queda en 0
      expect(p.avance, 0);
      final medio = ProgresoConductor.fromJson(_progreso(puntos: 450));
      expect(medio.avance, closeTo(0.5, 0.001));
    });

    test('nivel máximo: avance completo', () {
      final p = ProgresoConductor.fromJson(
        _progreso(
          puntos: 3000,
          nivel: {'numero': 7, 'nombre': 'Leyenda', 'puntos': 2500},
          siguiente: null,
        ),
      );
      expect(p.siguienteNivel, isNull);
      expect(p.avance, 1);
    });

    test('lo que falta de cada pendiente', () {
      final logros = ProgresoConductor.fromJson(_progreso()).logros;
      expect(logros[2].faltante, 'Aún no lo consigues');
      expect(logros[3].faltante, 'Racha actual: 3 de 5');
      expect(logros[4].faltante, 'Te faltan 3 viajes');
      expect(logros[5].faltante, '63 de 100 km');
      const uno = Logro(
        codigo: 'constante',
        nombre: 'Constante',
        descripcion: '',
        tipo: TipoProgreso.viajes,
        meta: 10,
        progreso: 9,
      );
      expect(uno.faltante, 'Te falta 1 viaje');
    });

    test('la recompensa viene en la respuesta del PATCH', () {
      final json = {
        'id': 7,
        'estado': 'finalizado',
        'fecha_inicio': '2026-11-13T12:00:00Z',
        'drivescore': 86,
        'puntaje_frenadas': 70,
        'puntaje_aceleraciones': 100,
        'puntaje_giros': 76,
        'puntaje_velocidad': 100,
        'recompensa': {
          'puntos': 31,
          'subio_de_nivel': true,
          'nivel': {'numero': 2, 'nombre': 'Aprendiz', 'puntos': 100},
          'logros_nuevos': [
            {
              'codigo': 'primer_viaje',
              'nombre': 'Primer viaje',
              'descripcion': 'Completa tu primer viaje.',
            },
          ],
        },
      };
      final recompensa = Recorrido.fromJson(json).recompensa!;
      expect(recompensa.puntos, 31);
      expect(recompensa.hayNovedades, isTrue);
      expect(recompensa.logrosNuevos.single.nombre, 'Primer viaje');
      // Descartado o backend anterior: sin recompensa
      expect(
        Recorrido.fromJson({...json, 'recompensa': null}).recompensa,
        isNull,
      );
      expect(
        Recorrido.fromJson({...json}..remove('recompensa')).recompensa,
        isNull,
      );
      // Backend anterior a HU-23: sin desafíos ni bono
      expect(recompensa.desafiosCompletados, isEmpty);
      expect(recompensa.bono, isNull);
      expect(recompensa.puntosTotal, 31);
    });

    test('desafíos completados y bono (HU-23)', () {
      final recompensa = RecompensaViaje.fromJson({
        'puntos': 33,
        'subio_de_nivel': false,
        'nivel': {'numero': 4, 'nombre': 'Conductor seguro', 'puntos': 600},
        'logros_nuevos': <Object>[],
        'desafios_completados': [
          {
            'codigo': 'semana_activa',
            'tipo': 'constancia',
            'nombre': 'Semana activa',
            'puntos': 150,
            'categoria': null,
          },
          {
            'codigo': 'sin_giros_agresivos',
            'tipo': 'punto_debil',
            'nombre': 'Sin giros agresivos',
            'puntos': 200,
            'categoria': 'giros',
          },
        ],
        'bono_semanal': 100,
      })!;
      expect(recompensa.desafiosCompletados, hasLength(2));
      expect(recompensa.desafiosCompletados[0].categoria, isNull);
      expect(
        recompensa.desafiosCompletados[1].categoria,
        CategoriaPuntaje.giros,
      );
      expect(recompensa.bono, 100);
      // Viaje 33 + desafíos 150 + 200 + bono 100
      expect(recompensa.puntosTotal, 483);
      // Sin subir de nivel ni logros, completar un desafío ya es una novedad
      expect(recompensa.hayNovedades, isTrue);
    });

    test('sin nivel, logros ni desafíos no hay novedades', () {
      final recompensa = RecompensaViaje.fromJson({
        'puntos': 25,
        'subio_de_nivel': false,
        'nivel': {'numero': 2, 'nombre': 'Aprendiz', 'puntos': 100},
        'logros_nuevos': <Object>[],
        'desafios_completados': <Object>[],
        'bono_semanal': null,
      })!;
      expect(recompensa.hayNovedades, isFalse);
      expect(recompensa.puntosTotal, 25);
    });
  });

  group('Nivel en Perfil', () {
    testWidgets('nivel, puntos, lo que falta y los logros', (tester) async {
      await _mostrar(tester, () => _progreso(puntos: 450));
      expect(find.text('NIVEL 3'), findsOneWidget);
      expect(find.text('Conductor'), findsOneWidget);
      expect(find.text('450 pts'), findsOneWidget);
      expect(
        find.text('Te faltan 150 pts para Conductor seguro'),
        findsOneWidget,
      );
      expect(find.text('2 de 6'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.value, closeTo(0.5, 0.001));
    });

    testWidgets('nivel máximo', (tester) async {
      await _mostrar(
        tester,
        () => _progreso(
          puntos: 3000,
          nivel: {'numero': 7, 'nombre': 'Leyenda', 'puntos': 2500},
          siguiente: null,
        ),
      );
      expect(find.text('Leyenda'), findsOneWidget);
      expect(find.text('Alcanzaste el nivel máximo'), findsOneWidget);
    });

    testWidgets('abre los logros', (tester) async {
      await _mostrar(tester, _progreso);
      await tester.tap(find.text('Logros'));
      await tester.pumpAndSettle();
      expect(find.byType(LogrosPantalla), findsOneWidget);
    });

    testWidgets('error: reintentar', (tester) async {
      final repositorio = await _mostrar(
        tester,
        () => throw const ErrorApi(mensaje: 'Sin conexión'),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repositorio.pedidos, 2);
    });
  });

  group('Pantalla de logros', () {
    testWidgets('desbloqueados con su fecha y pendientes con lo que falta', (
      tester,
    ) async {
      await _mostrar(tester, _progreso, inicial: Rutas.logros);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('de 6 desbloqueados'), findsOneWidget);
      expect(find.text('DESBLOQUEADOS'), findsOneWidget);
      expect(find.text('Desbloqueado el 3 de noviembre'), findsOneWidget);
      expect(find.text('Desbloqueado el 5 de noviembre'), findsOneWidget);
      expect(find.text('PENDIENTES'), findsOneWidget);
      expect(find.text('Racha actual: 3 de 5'), findsOneWidget);
      expect(find.text('Te faltan 3 viajes'), findsOneWidget);
      expect(find.text('63 de 100 km'), findsOneWidget);
      // Resumen + 3 pendientes con avance (el de un solo viaje no tiene barra)
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });

    testWidgets('sin desbloqueados: solo pendientes', (tester) async {
      await _mostrar(
        tester,
        () => {
          ..._progreso(),
          'logros': [_logro('primer_viaje', 'Primer viaje')],
        },
        inicial: Rutas.logros,
      );
      expect(find.text('DESBLOQUEADOS'), findsNothing);
      expect(find.text('PENDIENTES'), findsOneWidget);
      expect(find.text('Te falta 1 viaje'), findsOneWidget);
    });

    testWidgets('error: aviso y reintentar', (tester) async {
      await _mostrar(
        tester,
        () => throw const ErrorApi(mensaje: 'Sin conexión'),
        inicial: Rutas.logros,
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
