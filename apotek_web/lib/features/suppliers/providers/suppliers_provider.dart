import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class SuppliersState {
  final List<Map<String, dynamic>> suppliers;
  final bool isLoading;
  final String? error;

  SuppliersState({this.suppliers = const [], this.isLoading = false, this.error});

  SuppliersState copyWith({
    List<Map<String, dynamic>>? suppliers,
    bool? isLoading,
    String? error,
  }) =>
      SuppliersState(
        suppliers: suppliers ?? this.suppliers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SuppliersNotifier extends StateNotifier<SuppliersState> {
  final Dio _dio = ApiClient.createDio();

  SuppliersNotifier() : super(SuppliersState()) {
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/suppliers');
      final suppliers = List<Map<String, dynamic>>.from(response.data);
      state = state.copyWith(suppliers: suppliers, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data supplier',
      );
    }
  }

  Future<bool> createSupplier(Map<String, dynamic> data) async {
    try {
      await _dio.post('/suppliers', data: data);
      await loadSuppliers();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal membuat supplier',
      );
      return false;
    }
  }

  Future<bool> updateSupplier(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/suppliers/$id', data: data);
      await loadSuppliers();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal memperbarui supplier',
      );
      return false;
    }
  }

  Future<bool> deleteSupplier(String id) async {
    try {
      await _dio.delete('/suppliers/$id');
      await loadSuppliers();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menghapus supplier',
      );
      return false;
    }
  }
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, SuppliersState>((ref) => SuppliersNotifier());
