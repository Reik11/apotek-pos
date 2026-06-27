import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user_model.dart';

// State untuk auth
class AuthState {
  final bool isLoading;
  final bool isInitialized;
  final UserModel? user;
  final String? token;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    UserModel? user,
    String? token,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio = ApiClient.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier() : super(AuthState()) {
    _checkToken();
  }

  // Cek token saat app pertama dibuka
  Future<void> _checkToken() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final userJson = await _storage.read(key: 'user_data');
      if (token != null && userJson != null) {
        final userMap = jsonDecode(userJson);
        final user = UserModel.fromJson(userMap);
        state = AuthState(
          user: user,
          token: token,
          isInitialized: true,
        );
      } else {
        state = state.copyWith(isInitialized: true);
      }
    } catch (e) {
      state = state.copyWith(isInitialized: true);
    }
  }

  String _parseError(DioException e, String defaultMsg) {
    final dynamic rawMessage = e.response?.data['message'];
    if (rawMessage is List) {
      return rawMessage.join(', ');
    } else if (rawMessage is String) {
      return rawMessage;
    }
    return defaultMsg;
  }

  // Clear auth error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  // LOGIN
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['accessToken'];
      final user = UserModel.fromJson(response.data['user']);

      // Simpan token & data user
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));

      state = state.copyWith(isLoading: false, user: user, token: token);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Koneksi ke server gagal atau salah password.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan tidak terduga: $e');
      return false;
    }
  }

  // REQUEST OTP PENDAFTARAN
  Future<bool> requestRegisterOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/auth/register/request-otp', data: {'email': email});
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Gagal mengirim OTP. Email mungkin sudah terdaftar.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // REGISTER (Pasien) — dengan verifikasi OTP
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'otp': otp,
        'role': 'PASIEN',
      });

      final token = response.data['accessToken'];
      final user = UserModel.fromJson(response.data['user']);

      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
      
      state = state.copyWith(isLoading: false, user: user, token: token);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Pendaftaran gagal. Cek kembali kode OTP Anda.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // REQUEST OTP GANTI PASSWORD
  Future<bool> requestChangePasswordOtp() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = state.token;
      await _dio.post(
        '/auth/change-password/request-otp',
        options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Gagal mengirim OTP. Coba lagi.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthState(isInitialized: true);
  }

  // REQUEST PASSWORD RESET OTP
  Future<bool> requestPasswordResetOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/auth/forgot-password/request', data: {'email': email});
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Gagal meminta kode OTP. Cek kembali email Anda.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // RESET PASSWORD WITH OTP
  Future<bool> resetPasswordWithOtp(String email, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/auth/forgot-password/reset', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Gagal mereset kata sandi. Cek kembali kode OTP.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // GOOGLE LOGIN
  Future<bool> loginWithGoogle(String idToken) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/auth/google', data: {
        'idToken': idToken,
      });

      final token = response.data['accessToken'];
      final user = UserModel.fromJson(response.data['user']);

      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));

      state = state.copyWith(isLoading: false, user: user, token: token);
      return true;
    } on DioException catch (e) {
      final message = _parseError(e, 'Gagal masuk menggunakan Google.');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // UPDATE user data di state (setelah edit profil)
  void refreshUser(Map<String, dynamic> userData) async {
    final user = UserModel.fromJson(userData);
    state = state.copyWith(user: user);
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
