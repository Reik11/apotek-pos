import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Otomatis pilih URL berdasarkan platform
  static String get baseUrl {
    if (kIsWeb) {
      // Di production (Netlify), gunakan URL Render backend. Di local, gunakan localhost.
      if (kReleaseMode) {
        return 'https://apotek-backend.onrender.com';
      }
      return 'http://localhost:3000';
    } else {
      // Di HP Android fisik (Release Mode), gunakan URL Render backend.
      // Di Emulator (Debug Mode), gunakan 10.0.2.2 untuk mengakses localhost.
      if (kReleaseMode) {
        return 'https://apotek-backend.onrender.com';
      }
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
