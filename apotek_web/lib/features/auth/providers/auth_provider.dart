import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user_model.dart';

// State untuk auth
class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? token;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? token,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
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
    final token = await _storage.read(key: 'access_token');
    final userJson = await _storage.read(key: 'user_data');
    if (token != null && userJson != null) {
      // Token ada, user sudah login sebelumnya
    }
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

      state = state.copyWith(isLoading: false, user: user, token: token);
      return true;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Koneksi ke server gagal atau salah password.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan tidak terduga: $e');
      return false;
    }
  }

  // REGISTER (Pasien)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'PASIEN',
      });

      final token = response.data['accessToken'];
      final user = UserModel.fromJson(response.data['user']);

      await _storage.write(key: 'access_token', value: token);
      state = state.copyWith(isLoading: false, user: user, token: token);
      return true;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Pendaftaran gagal. Email mungkin sudah terdaftar.';
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
    state = AuthState();
  }

  // UPDATE user data di state (setelah edit profil)
  void refreshUser(Map<String, dynamic> userData) {
    final user = UserModel.fromJson(userData);
    state = state.copyWith(user: user);
  }
}


// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
