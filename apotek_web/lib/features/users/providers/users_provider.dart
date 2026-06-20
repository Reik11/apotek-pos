import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class UsersState {
  final List<Map<String, dynamic>> users;
  final bool isLoading;
  final String? error;

  UsersState({this.users = const [], this.isLoading = false, this.error});

  UsersState copyWith({
    List<Map<String, dynamic>>? users,
    bool? isLoading,
    String? error,
  }) =>
      UsersState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class UsersNotifier extends StateNotifier<UsersState> {
  final Dio _dio = ApiClient.createDio();

  UsersNotifier() : super(UsersState()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/users');
      final users = List<Map<String, dynamic>>.from(response.data);
      state = state.copyWith(users: users, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data pengguna',
      );
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      await _dio.post('/users', data: data);
      await loadUsers();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal membuat pengguna',
      );
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      await _dio.delete('/users/$id');
      await loadUsers();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menghapus pengguna',
      );
      return false;
    }
  }
}

final usersProvider =
    StateNotifierProvider<UsersNotifier, UsersState>((ref) => UsersNotifier());
