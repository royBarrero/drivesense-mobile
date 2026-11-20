import 'package:dio/dio.dart';
import 'package:drivesense/app/theme.dart';
import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/features/asistente/data/assistant_repository.dart';
import 'package:drivesense/features/asistente/models/assistant_message.dart';
import 'package:drivesense/features/asistente/presentation/assistant_screen.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
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

/// Repositorio sin red: guarda las conversaciones que recibe.
class _AsistenteFalso extends AsistenteRepositorio {
  _AsistenteFalso(this.responder_) : super(Dio());

  Future<MensajeAsistente> Function(List<MensajeAsistente>) responder_;
  final conversaciones = <List<MensajeAsistente>>[];

  @override
  Future<List<String>> sugerencias() async => [
    '¿Cómo inicio un viaje?',
    '¿Dónde veo mis puntajes?',
  ];

  @override
  Future<MensajeAsistente> responder(List<MensajeAsistente> conversacion) {
    conversaciones.add(List.of(conversacion));
    return responder_(conversacion);
  }
}

Future<MensajeAsistente> _conIa(List<MensajeAsistente> _) async =>
    const MensajeAsistente(
      rol: RolMensaje.asistente,
      texto: 'En Inicio, toca "Iniciar recorrido".',
      generadaPorIa: true,
    );

Future<_AsistenteFalso> _mostrar(
  WidgetTester tester, {
  Future<MensajeAsistente> Function(List<MensajeAsistente>) responder = _conIa,
}) async {
  final repositorio = _AsistenteFalso(responder);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionFija.new),
        asistenteRepositorioProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp(theme: temaClaro(), home: const AsistentePantalla()),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  group('Modelo', () {
    test('lee la respuesta y arma el JSON de la API', () {
      final respuesta = MensajeAsistente.respuesta({
        'texto': 'Hola',
        'generada_por_ia': true,
      });
      expect(respuesta.rol, RolMensaje.asistente);
      expect(respuesta.generadaPorIa, isTrue);
      expect(
        const MensajeAsistente(
          rol: RolMensaje.usuario,
          texto: 'Hola',
        ).toApiJson(),
        {'rol': 'usuario', 'texto': 'Hola'},
      );
    });

    test('sin generada_por_ia es una respuesta fija', () {
      expect(
        MensajeAsistente.respuesta({'texto': 'Hola'}).generadaPorIa,
        isFalse,
      );
    });
  });

  group('Pantalla', () {
    testWidgets('saluda y ofrece las sugerencias', (tester) async {
      await _mostrar(tester);
      expect(find.text(saludoAsistente), findsOneWidget);
      expect(find.text('¿Cómo inicio un viaje?'), findsOneWidget);
      expect(find.byTooltip('Nueva conversación'), findsNothing);
    });

    testWidgets('tocar una sugerencia la pregunta y muestra la respuesta '
        'con la cápsula Con IA', (tester) async {
      final repositorio = await _mostrar(tester);
      await tester.tap(find.text('¿Cómo inicio un viaje?'));
      await tester.pumpAndSettle();

      expect(
        repositorio.conversaciones.single.single.texto,
        '¿Cómo inicio un viaje?',
      );
      expect(find.text('En Inicio, toca "Iniciar recorrido".'), findsOneWidget);
      expect(find.text('CON IA'), findsOneWidget);
      // Ya hay conversación: sin sugerencias
      expect(find.text('¿Dónde veo mis puntajes?'), findsNothing);
    });

    testWidgets('escribir y enviar manda toda la conversación', (tester) async {
      final repositorio = await _mostrar(tester);
      await tester.enterText(find.byType(TextField), '¿Cómo inicio un viaje?');
      // El botón se activa al redibujarse con el texto
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enviar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  ¿Y cómo lo termino?  ');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enviar'));
      await tester.pumpAndSettle();

      final ultima = repositorio.conversaciones.last;
      expect(ultima.map((m) => m.rol), [
        RolMensaje.usuario,
        RolMensaje.asistente,
        RolMensaje.usuario,
      ]);
      expect(ultima.last.texto, '¿Y cómo lo termino?');
    });

    testWidgets('una respuesta fija no lleva la cápsula', (tester) async {
      await _mostrar(
        tester,
        responder: (_) async => const MensajeAsistente(
          rol: RolMensaje.asistente,
          texto: 'Toca la pestaña "Viajes".',
        ),
      );
      await tester.tap(find.text('¿Dónde veo mis puntajes?'));
      await tester.pumpAndSettle();
      expect(find.text('Toca la pestaña "Viajes".'), findsOneWidget);
      expect(find.text('CON IA'), findsNothing);
    });

    testWidgets('con error muestra el mensaje y Reintentar vuelve a pedir', (
      tester,
    ) async {
      var falla = true;
      final repositorio = await _mostrar(
        tester,
        responder: (c) async {
          if (falla) throw const ErrorApi(mensaje: ErrorApi.sinConexion);
          return _conIa(c);
        },
      );
      await tester.tap(find.text('¿Cómo inicio un viaje?'));
      await tester.pumpAndSettle();
      expect(find.text(ErrorApi.sinConexion), findsOneWidget);

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text(ErrorApi.sinConexion), findsNothing);
      expect(find.text('En Inicio, toca "Iniciar recorrido".'), findsOneWidget);
      // La pregunta no se duplicó al reintentar
      expect(repositorio.conversaciones.last.length, 1);
    });

    testWidgets('Nueva conversación vuelve al saludo con sugerencias', (
      tester,
    ) async {
      await _mostrar(tester);
      await tester.tap(find.text('¿Cómo inicio un viaje?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nueva conversación'));
      await tester.pumpAndSettle();
      expect(find.text('En Inicio, toca "Iniciar recorrido".'), findsNothing);
      expect(find.text('¿Cómo inicio un viaje?'), findsOneWidget);
    });
  });

  test('envía como mucho los últimos 20 mensajes', () async {
    final enviados = <Object?>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (opciones, manejador) {
            enviados.add(opciones.data);
            manejador.resolve(
              Response(
                requestOptions: opciones,
                data: {'texto': 'ok', 'generada_por_ia': true},
              ),
            );
          },
        ),
      );
    final conversacion = [
      for (var i = 0; i < 25; i++)
        MensajeAsistente(
          rol: i.isEven ? RolMensaje.usuario : RolMensaje.asistente,
          texto: '$i',
        ),
    ];
    await AsistenteRepositorio(dio).responder(conversacion);
    final mensajes = (enviados.single! as Map)['mensajes'] as List;
    expect(mensajes.length, maximoMensajesEnviados);
    expect((mensajes.last as Map)['texto'], '24');
  });
}
