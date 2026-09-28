import 'package:drivesense/core/api/api_error.dart';
import 'package:drivesense/core/storage/token_storage.dart';
import 'package:drivesense/features/auth/data/auth_repository.dart';
import 'package:drivesense/features/auth/data/user_storage.dart';
import 'package:drivesense/features/auth/models/user.dart';
import 'package:drivesense/features/auth/providers/session_provider.dart';
import 'package:drivesense/features/recorridos/data/trip_local_storage.dart';
import 'package:drivesense/features/recorridos/data/trips_repository.dart';
import 'package:drivesense/features/recorridos/models/trip.dart';
import 'package:drivesense/features/recorridos/models/trip_accumulator.dart';
import 'package:drivesense/features/recorridos/providers/pending_summary_provider.dart';
import 'package:drivesense/features/recorridos/providers/trip_provider.dart';
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

class _TokenFalso implements AlmacenToken {
  String? token = 'jwt';

  @override
  Future<String?> leer() async => token;

  @override
  Future<void> guardar(String valor) async => token = valor;

  @override
  Future<void> borrar() async => token = null;
}

class _UsuarioFalso implements AlmacenUsuario {
  Usuario? usuario;

  @override
  Future<Usuario?> leer() async => usuario;

  @override
  Future<void> guardar(Usuario valor) async => usuario = valor;

  @override
  Future<void> borrar() async => usuario = null;
}

/// `GET /auth/yo` responde lo que se le indique.
class _AuthFalso implements AuthRepositorio {
  _AuthFalso(this.respuesta);

  final Object respuesta;

  @override
  Future<Usuario> obtenerUsuarioActual() async {
    final r = respuesta;
    if (r is Usuario) return r;
    throw r;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _sesion(
  Object respuesta,
  _TokenFalso token,
  _UsuarioFalso usuarios,
) {
  final contenedor = ProviderContainer(
    overrides: [
      almacenTokenProvider.overrideWithValue(token),
      almacenUsuarioProvider.overrideWithValue(usuarios),
      authRepositorioProvider.overrideWithValue(_AuthFalso(respuesta)),
    ],
  );
  addTearDown(contenedor.dispose);
  return contenedor;
}

class _SesionFija extends SesionNotifier {
  @override
  Future<Usuario?> build() async => _usuario;
}

class _PendienteFijo extends ResumenPendienteNotifier {
  @override
  Future<ResumenRecorrido?> build() async => null;
}

class _AlmacenRecorridoFalso implements AlmacenRecorrido {
  ViajeActivo? viaje;
  ResumenRecorrido? resumen;

  @override
  Future<ViajeActivo?> leerViaje(int usuarioId) async => viaje;

  @override
  Future<void> guardarViaje(int usuarioId, ViajeActivo valor) async =>
      viaje = valor;

  @override
  Future<void> borrarViaje(int usuarioId) async => viaje = null;

  @override
  Future<ResumenRecorrido?> leerResumen(int usuarioId) async => resumen;

  @override
  Future<void> guardarResumen(int usuarioId, ResumenRecorrido valor) async =>
      resumen = valor;

  @override
  Future<void> borrarResumen(int usuarioId) async => resumen = null;
}

/// `GET /recorridos/activo` devuelve siempre [activo].
class _RecorridosFalso implements RecorridosRepositorio {
  _RecorridosFalso(this.activo);

  final Recorrido? activo;

  @override
  Future<Recorrido?> obtenerActivo() async => activo;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ResumenRecorrido _resumen(int recorridoId) => ResumenRecorrido(
  recorridoId: recorridoId,
  fechaFin: DateTime.utc(2026, 9, 27, 17),
  distanciaM: 10,
  duracionS: 120,
  velocidadMaximaKmh: 1,
  velocidadPromedioKmh: 0,
  latitudFin: 0,
  longitudFin: 0,
);

Future<EstadoViaje> _restaurar(
  _AlmacenRecorridoFalso almacen,
  Recorrido? activo,
) async {
  final contenedor = ProviderContainer(
    overrides: [
      sesionProvider.overrideWith(_SesionFija.new),
      resumenPendienteProvider.overrideWith(_PendienteFijo.new),
      almacenRecorridoProvider.overrideWithValue(almacen),
      recorridosRepositorioProvider.overrideWithValue(_RecorridosFalso(activo)),
    ],
  );
  addTearDown(contenedor.dispose);
  await contenedor.read(sesionProvider.future);
  return contenedor.read(viajeProvider.future);
}

void main() {
  group('Sesión sin conexión', () {
    test('entra con el último usuario guardado', () async {
      final usuarios = _UsuarioFalso()..usuario = _usuario;
      final contenedor = _sesion(
        const ErrorApi(mensaje: ErrorApi.sinConexion),
        _TokenFalso(),
        usuarios,
      );

      final usuario = await contenedor.read(sesionProvider.future);
      expect(usuario?.email, 'ana@prueba.com');
    });

    test(
      'sin usuario guardado sigue mostrando el error (Reintentar)',
      () async {
        final contenedor = _sesion(
          const ErrorApi(mensaje: ErrorApi.sinConexion),
          _TokenFalso(),
          _UsuarioFalso(),
        );

        await expectLater(
          contenedor.read(sesionProvider.future),
          throwsA(isA<ErrorApi>()),
        );
      },
    );

    test('un 401 borra el token y el usuario guardado', () async {
      final token = _TokenFalso();
      final usuarios = _UsuarioFalso()..usuario = _usuario;
      final contenedor = _sesion(
        const ErrorApi(mensaje: 'Sesión inválida o expirada', codigo: 401),
        token,
        usuarios,
      );

      expect(await contenedor.read(sesionProvider.future), isNull);
      expect(token.token, isNull);
      expect(usuarios.usuario, isNull);
    });

    test('con conexión guarda el usuario para la próxima vez', () async {
      final usuarios = _UsuarioFalso();
      final contenedor = _sesion(_usuario, _TokenFalso(), usuarios);

      await contenedor.read(sesionProvider.future);
      expect(usuarios.usuario?.id, 1);
    });
  });

  group('Restaurar el viaje al abrir la app', () {
    final activo = Recorrido(
      id: 8,
      estado: EstadoRecorrido.enCurso,
      fechaInicio: DateTime.utc(2026, 9, 27, 16, 54),
    );

    test(
      'un viaje con el resumen pendiente no se ofrece como interrumpido',
      () async {
        final almacen = _AlmacenRecorridoFalso()..resumen = _resumen(8);
        expect(await _restaurar(almacen, activo), isA<SinViaje>());
      },
    );

    test('un viaje en curso sin resumen pendiente sí se ofrece', () async {
      final almacen = _AlmacenRecorridoFalso()
        ..viaje = ViajeActivo(
          recorridoId: 8,
          fechaInicioServidor: activo.fechaInicio,
          acumulador: AcumuladorRecorrido(inicio: activo.fechaInicio),
        );
      expect(await _restaurar(almacen, activo), isA<ViajeInterrumpido>());
    });
  });
}
