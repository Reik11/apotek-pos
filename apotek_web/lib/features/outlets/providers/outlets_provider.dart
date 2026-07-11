import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';

class OutletsState {
  final List<Map<String, dynamic>> outlets;
  final Map<String, dynamic>? selectedOutlet; // Selected outlet for Patient Portal
  final bool isLoading;
  final String? error;

  OutletsState({
    this.outlets = const [],
    this.selectedOutlet,
    this.isLoading = false,
    this.error,
  });

  OutletsState copyWith({
    List<Map<String, dynamic>>? outlets,
    Map<String, dynamic>? selectedOutlet,
    bool? isLoading,
    String? error,
  }) =>
      OutletsState(
        outlets: outlets ?? this.outlets,
        selectedOutlet: selectedOutlet ?? this.selectedOutlet,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class OutletsNotifier extends StateNotifier<OutletsState> {
  final Dio _dio = ApiClient.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  OutletsNotifier() : super(OutletsState()) {
    loadOutlets();
    _loadSelectedOutlet();
  }

  // Load selected outlet from secure storage
  Future<void> _loadSelectedOutlet() async {
    try {
      final outletId = await _storage.read(key: 'selected_outlet_id').timeout(const Duration(seconds: 1));
      final outletName = await _storage.read(key: 'selected_outlet_name').timeout(const Duration(seconds: 1));
      if (outletId != null && outletName != null) {
        state = state.copyWith(
          selectedOutlet: {
            'id': outletId,
            'name': outletName,
          },
        );
      }
    } catch (_) {}
  }

  // Select outlet for patient
  Future<void> selectOutlet(Map<String, dynamic>? outlet) async {
    if (outlet == null) {
      try {
        await _storage.delete(key: 'selected_outlet_id').timeout(const Duration(seconds: 1));
        await _storage.delete(key: 'selected_outlet_name').timeout(const Duration(seconds: 1));
      } catch (_) {}
      state = OutletsState(
        outlets: state.outlets,
        selectedOutlet: null,
        isLoading: state.isLoading,
        error: state.error,
      );
    } else {
      try {
        await _storage.write(key: 'selected_outlet_id', value: outlet['id']).timeout(const Duration(seconds: 2));
        await _storage.write(key: 'selected_outlet_name', value: outlet['name']).timeout(const Duration(seconds: 2));
      } catch (_) {}
      state = state.copyWith(selectedOutlet: outlet);
    }
  }

  // Load all outlets
  Future<void> loadOutlets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/outlets');
      final outlets = List<Map<String, dynamic>>.from(response.data);
      state = state.copyWith(outlets: outlets, isLoading: false);
      
      // If we have a selected outlet, update its info if it changed
      if (state.selectedOutlet != null) {
        final currentId = state.selectedOutlet!['id'];
        final matched = outlets.firstWhere(
          (o) => o['id'] == currentId,
          orElse: () => {},
        );
        if (matched.isNotEmpty) {
          state = state.copyWith(selectedOutlet: matched);
        }
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data outlet',
      );
    }
  }

  // Create outlet
  Future<bool> createOutlet(Map<String, dynamic> data) async {
    try {
      await _dio.post('/outlets', data: data);
      await loadOutlets();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal membuat outlet',
      );
      return false;
    }
  }

  // Update outlet
  Future<bool> updateOutlet(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/outlets/$id', data: data);
      await loadOutlets();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal memperbarui outlet',
      );
      return false;
    }
  }

  // Delete outlet
  Future<bool> deleteOutlet(String id) async {
    try {
      await _dio.delete('/outlets/$id');
      await loadOutlets();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menghapus outlet',
      );
      return false;
    }
  }
}

final outletsProvider =
    StateNotifierProvider<OutletsNotifier, OutletsState>((ref) => OutletsNotifier());
