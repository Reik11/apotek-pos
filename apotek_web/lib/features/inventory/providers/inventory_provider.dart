import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/drug_model.dart';

class InventoryState {
  final List<DrugModel> drugs;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  InventoryState({
    this.drugs = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  InventoryState copyWith({
    List<DrugModel>? drugs,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return InventoryState(
      drugs: drugs ?? this.drugs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Filter obat berdasarkan search
  List<DrugModel> get filteredDrugs {
    if (searchQuery.isEmpty) return drugs;
    return drugs
        .where((d) =>
            d.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (d.genericName?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false))
        .toList();
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final Dio _dio = ApiClient.createDio();

  InventoryNotifier() : super(InventoryState()) {
    loadDrugs();
  }

  // Load semua obat
  Future<void> loadDrugs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/drugs');
      final drugs =
          (response.data as List).map((d) => DrugModel.fromJson(d)).toList();
      state = state.copyWith(drugs: drugs, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data',
      );
    }
  }

  // Update search query
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // Tambah obat baru
  Future<bool> addDrug(Map<String, dynamic> data) async {
    try {
      await _dio.post('/drugs', data: data);
      await loadDrugs();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menambah obat',
      );
      return false;
    }
  }

  // Tambah batch/stok
  Future<bool> addBatch(Map<String, dynamic> data) async {
    try {
      await _dio.post('/drugs/batch', data: data);
      await loadDrugs();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menambah stok',
      );
      return false;
    }
  }

  // Cari info obat dari RxNorm + FDA
  Future<Map<String, dynamic>?> searchDrugInfo(String name) async {
    try {
      final response = await _dio.get('/external/drug-info?name=$name');
      return response.data;
    } catch (e) {
      return null;
    }
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});
