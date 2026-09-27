import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import '../config.dart';

/// Cliente HTTP del backend. Añade `Authorization: Bearer <token>` si hay sesión.
///
/// Los repositorios convierten `DioException` en `ErrorApi` con `ErrorApi.desde`.
final clienteApiProvider = Provider<Dio>((ref) {
  final almacenToken = ref.watch(almacenTokenProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: '$apiUrl/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (opciones, handler) async {
        final token = await almacenToken.leer();
        if (token != null) {
          opciones.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(opciones);
      },
    ),
  );
  return dio;
});
