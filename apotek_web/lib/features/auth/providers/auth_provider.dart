import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user_model.dart';

// State untuk auth
class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
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

      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Login gagal';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthState();
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
