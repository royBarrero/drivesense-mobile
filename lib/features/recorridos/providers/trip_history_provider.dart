import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../auth/providers/session_provider.dart';
import '../data/trips_repository.dart';
import '../models/trip_history.dart';

/// Historial de un periodo: los viajes cargados hasta ahora y el resumen.
class EstadoHistorial {
  const EstadoHistorial({
    required this.desde,
    required this.recorridos,
    required this.resumen,
    required this.siguiente,
    required this.sinViajes,
    this.cargandoMas = false,
    this.errorMas,
  });

  /// Inicio del periodo con el que se pidió la primera página; las siguientes
  /// usan el mismo aunque cambie el día.
  final DateTime? desde;
  final List<RecorridoHistorial> recorridos;
  final ResumenPeriodo resumen;

  /// Cursor de la página siguiente; nulo si ya están todos.
  final int? siguiente;

  /// El conductor no tiene ningún viaje finalizado (en ningún periodo).
  final bool sinViajes;

  final bool cargandoMas;

  /// Error al cargar la página siguiente; la lista ofrece reintentar.
  final String? errorMas;

  bool get hayMas => siguiente != null;
}

/// Historial de viajes finalizados de un periodo (HU-06), paginado por cursor.
class HistorialNotifier extends AsyncNotifier<EstadoHistorial> {
  HistorialNotifier(this.periodo);

  final PeriodoHistorial periodo;

  static const tamanoPagina = 20;

  @override
  Future<EstadoHistorial> build() async {
    final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
    if (usuarioId == null) {
      return const EstadoHistorial(
        desde: null,
        recorridos: [],
        resumen: ResumenPeriodo(viajes: 0, distanciaM: 0, duracionS: 0),
        siguiente: null,
        sinViajes: true,
      );
    }

    final desde = periodo.desde(DateTime.now());
    final pagina = await _pedir((r) => r.listar(desde: desde));
    // Periodo vacío: se consulta si hay algún viaje para saber qué pantalla mostrar
    final sinViajes =
        pagina.recorridos.isEmpty &&
        (periodo == PeriodoHistorial.todos ||
            (await _pedir((r) => r.listar(limite: 1))).recorridos.isEmpty);
    return EstadoHistorial(
      desde: desde,
      recorridos: pagina.recorridos,
      resumen: pagina.resumen!,
      siguiente: pagina.siguiente,
      sinViajes: sinViajes,
    );
  }

  /// Pide la página siguiente; no hace nada si ya se está cargando o no hay más.
  Future<void> cargarMas() async {
    final actual = state.value;
    if (state.isLoading ||
        actual == null ||
        !actual.hayMas ||
        actual.cargandoMas) {
      return;
    }

    final cargando = EstadoHistorial(
      desde: actual.desde,
      recorridos: actual.recorridos,
      resumen: actual.resumen,
      siguiente: actual.siguiente,
      sinViajes: actual.sinViajes,
      cargandoMas: true,
    );
    state = AsyncData(cargando);

    EstadoHistorial siguiente;
    try {
      final pagina = await _pedir(
        (r) => r.listar(desde: actual.desde, antesDe: actual.siguiente),
      );
      siguiente = EstadoHistorial(
        desde: actual.desde,
        recorridos: [...actual.recorridos, ...pagina.recorridos],
        resumen: actual.resumen,
        siguiente: pagina.siguiente,
        sinViajes: actual.sinViajes,
      );
    } on ErrorApi catch (e) {
      siguiente = EstadoHistorial(
        desde: actual.desde,
        recorridos: actual.recorridos,
        resumen: actual.resumen,
        siguiente: actual.siguiente,
        sinViajes: actual.sinViajes,
        errorMas: e.mensaje,
      );
    }
    // Si mientras tanto se refrescó la lista, esta página ya no corresponde
    if (ref.mounted && identical(state.value, cargando)) {
      state = AsyncData(siguiente);
    }
  }

  Future<T> _pedir<T>(Future<T> Function(RecorridosRepositorio) peticion) =>
      pedirConSesion(ref, peticion);
}

/// Hace la petición y, si la sesión ya no es válida (401), la cierra.
Future<T> pedirConSesion<T>(
  Ref ref,
  Future<T> Function(RecorridosRepositorio) peticion,
) async {
  final repositorio = ref.read(recorridosRepositorioProvider);
  return conSesion(ref, () => peticion(repositorio));
}

final historialProvider =
    AsyncNotifierProvider.family<
      HistorialNotifier,
      EstadoHistorial,
      PeriodoHistorial
    >(
      HistorialNotifier.new,
      // Sin reintentos automáticos: la pantalla ofrece "Reintentar"
      retry: (intento, error) => null,
    );

/// Viaje finalizado más reciente (Inicio), o `null` si no hay ninguno.
final ultimoViajeProvider = FutureProvider<RecorridoHistorial?>((ref) async {
  final usuarioId = ref.watch(sesionProvider.select((s) => s.value?.id));
  if (usuarioId == null) return null;
  final pagina = await pedirConSesion(ref, (r) => r.listar(limite: 1));
  return pagina.recorridos.firstOrNull;
}, retry: (intento, error) => null);

/// Detalle de un viaje finalizado (HU-06).
final detalleRecorridoProvider = FutureProvider.autoDispose
    .family<RecorridoHistorial, int>(
      (ref, id) => pedirConSesion(ref, (r) => r.obtener(id)),
      retry: (intento, error) => null,
    );
