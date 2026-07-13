import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static String? activeToken;

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

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static Dio createDio({String? token}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? currentToken = token ?? activeToken;
          if (currentToken == null) {
            try {
              currentToken = await _storage.read(key: 'access_token').timeout(const Duration(seconds: 1));
              activeToken = currentToken; // Simpan di memori agar cepat
            } catch (_) {}
          }
          if (currentToken != null) {
            options.headers['Authorization'] = 'Bearer $currentToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            activeToken = null;
            try {
              await _storage.delete(key: 'access_token').timeout(const Duration(seconds: 1));
            } catch (_) {}
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

}
