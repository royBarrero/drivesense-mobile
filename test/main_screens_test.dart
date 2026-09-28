import 'package:drivesense/app/main_shell.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/inicio/presentation/home_screen.dart';
import 'package:drivesense/features/perfil/presentation/profile_screen.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/providers/pending_summary_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
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

class _ViajeFijo extends ViajeNotifier {
  _ViajeFijo(this._estado);

  final EstadoViaje _estado;

  @override
  Future<EstadoViaje> build() async => _estado;
}

class _PendienteFijo extends ResumenPendienteNotifier {
  _PendienteFijo(this._resumen);

  final ResumenRecorrido? _resumen;

  @override
  Future<ResumenRecorrido?> build() async => _resumen;
}

final _viaje = ViajeActivo(
  recorridoId: 3,
  fechaInicioServidor: DateTime.now(),
  acumulador: AcumuladorRecorrido(inicio: DateTime.now()),
);

final _resumen = ResumenRecorrido(
  recorridoId: 2,
  fechaFin: DateTime.now(),
  distanciaM: 1000,
  duracionS: 300,
  velocidadMaximaKmh: 40,
  velocidadPromedioKmh: 12,
  latitudFin: 0,
  longitudFin: 0,
);

Future<void> _mostrar(
  WidgetTester tester,
  Widget pantalla, {
  EstadoViaje viaje = const SinViaje(),
  ResumenRecorrido? pendiente,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        viajeProvider.overrideWith(() => _ViajeFijo(viaje)),
        resumenPendienteProvider.overrideWith(() => _PendienteFijo(pendiente)),
      ],
      child: MaterialApp(
        theme: temaClaro(),
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Inicio', () {
    testWidgets('sin viaje: saludo, iniciar recorrido y DriveScore vacío', (
      tester,
    ) async {
      await _mostrar(tester, const InicioPantalla());

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget, reason: 'iniciales');
      expect(find.text('¿Listo para salir?'), findsOneWidget);
      expect(find.text('Iniciar recorrido'), findsOneWidget);
      expect(
        find.text(
          'Tu DriveScore aparecerá aquí después de tus primeros viajes',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('pendiente de envío'), findsNothing);
    });

    testWidgets('con un viaje en curso no se ofrece iniciar otro', (
      tester,
    ) async {
      await _mostrar(
        tester,
        const InicioPantalla(),
        viaje: ViajeEnCurso(viaje: _viaje, ahora: DateTime.now()),
      );

      expect(find.text('Viaje en curso'), findsOneWidget);
      expect(find.text('Volver al viaje'), findsOneWidget);
      expect(find.text('Iniciar recorrido'), findsNothing);
    });

    testWidgets('un viaje interrumpido ofrece continuar o finalizar', (
      tester,
    ) async {
      await _mostrar(
        tester,
        const InicioPantalla(),
        viaje: ViajeInterrumpido(_viaje),
      );

      expect(find.text('Tienes un viaje sin terminar'), findsOneWidget);
      expect(find.text('Continuar viaje'), findsOneWidget);
      expect(find.text('Finalizar'), findsOneWidget);
    });

    testWidgets('avisa de un resumen pendiente de envío', (tester) async {
      await _mostrar(tester, const InicioPantalla(), pendiente: _resumen);
      expect(find.textContaining('pendiente de envío'), findsOneWidget);
    });
  });

  group('Perfil', () {
    testWidgets('muestra los datos y permite cerrar sesión', (tester) async {
      await _mostrar(tester, const PerfilPantalla());

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('ana@prueba.com'), findsOneWidget);
      expect(find.text('70000001'), findsOneWidget);
      expect(find.text('Conductor'), findsOneWidget);
      final boton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('durante un viaje no se puede cerrar sesión', (tester) async {
      await _mostrar(
        tester,
        const PerfilPantalla(),
        viaje: ViajeEnCurso(viaje: _viaje, ahora: DateTime.now()),
      );

      final boton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(boton.onPressed, isNull);
      expect(
        find.text('Finaliza el viaje en curso antes de cerrar sesión.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('la barra inferior marca la pestaña activa y avisa al tocar', (
    tester,
  ) async {
    int? seleccionada;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          bottomNavigationBar: BarraNavegacion(
            indiceActivo: 0,
            alSeleccionar: (indice) => seleccionada = indice,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.home), findsOneWidget, reason: 'Inicio activo');
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    expect(seleccionada, 2);

    // Ocupa solo su contenido, no toda la pantalla
    expect(tester.getSize(find.byType(BarraNavegacion)).height, lessThan(120));
  });
}
