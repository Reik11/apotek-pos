import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ProfileState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Dio _dio = ApiClient.createDio();

  ProfileNotifier() : super(ProfileState());

  // Update nama & email
  Future<bool> updateProfile({
    required String name,
    required String email,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _dio.put('/users/profile', data: {
        'name': name,
        'email': email,
      });
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Profil berhasil diperbarui!',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.response?.data['message'] ?? 'Gagal memperbarui profil',
      );
      return false;
    }
  }

  // Ganti password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _dio.put('/users/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Password berhasil diubah!',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.response?.data['message'] ?? 'Gagal mengubah password',
      );
      return false;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});
