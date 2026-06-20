import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Otomatis pilih URL berdasarkan platform
  static String get baseUrl {
    if (kIsWeb) {
      // Flutter Web mengakses localhost komputer
      return 'http://localhost:3000';
    } else {
      // Flutter Android Emulator mengakses localhost komputer lewat IP khusus Android
      return 'http://10.0.2.2:3000';
    }
  }

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.delete(key: 'access_token');
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }
}
