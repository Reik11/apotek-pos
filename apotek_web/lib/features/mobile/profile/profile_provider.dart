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

  // Minta OTP Ganti Password
  Future<bool> requestChangePasswordOtp() async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _dio.post('/auth/change-password/request-otp');
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Kode OTP ganti password telah dikirim ke email Anda.',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.response?.data['message'] ?? 'Gagal mengirim OTP ganti password',
      );
      return false;
    }
  }

  // Ganti password dengan verifikasi OTP
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _dio.put('/users/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'otp': otp,
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


  // Ambil data medis pasien
  Future<Map<String, dynamic>?> getMedicalProfile() async {
    try {
      final res = await _dio.get('/users/medical-profile');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }

  // Update data medis pasien
  Future<bool> updateMedicalProfile({
    String? birthDate,
    String? gender,
    double? weight,
    double? height,
    String? allergies,
    String? chronicDiseases,
    String? currentMedications,
    bool? isPregnant,
    bool? isBreastfeeding,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _dio.put('/users/medical-profile', data: {
        'birthDate': birthDate,
        'gender': gender,
        'weight': weight,
        'height': height,
        'allergies': allergies,
        'chronicDiseases': chronicDiseases,
        'currentMedications': currentMedications,
        'isPregnant': isPregnant,
        'isBreastfeeding': isBreastfeeding,
      });
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Data medis berhasil diperbarui!',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.response?.data['message'] ?? 'Gagal memperbarui data medis',
      );
      return false;
    }
  }
}


final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});
