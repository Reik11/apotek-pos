import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/drug_model.dart';

class InventoryState {
  final List<DrugModel> drugs;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final bool isSyncing;
  final String? selectedOutletId;

  InventoryState({
    this.drugs = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.isSyncing = false,
    this.selectedOutletId,
  });

  InventoryState copyWith({
    List<DrugModel>? drugs,
    bool? isLoading,
    String? error,
    String? searchQuery,
    bool? isSyncing,
    String? selectedOutletId,
  }) {
    return InventoryState(
      drugs: drugs ?? this.drugs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      isSyncing: isSyncing ?? this.isSyncing,
      selectedOutletId: selectedOutletId ?? this.selectedOutletId,
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
  Future<void> loadDrugs([String? outletId]) async {
    final targetOutletId = outletId ?? state.selectedOutletId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get(
        '/drugs',
        queryParameters: {
          if (targetOutletId != null && targetOutletId.isNotEmpty) 'outletId': targetOutletId,
        },
      );
      final drugs =
          (response.data as List).map((d) => DrugModel.fromJson(d)).toList();
      state = state.copyWith(
        drugs: drugs,
        isLoading: false,
        selectedOutletId: targetOutletId,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data',
      );
    }
  }

  // Ganti filter outlet
  Future<void> changeOutletFilter(String? outletId) async {
    state = state.copyWith(selectedOutletId: outletId ?? "");
    await loadDrugs(outletId ?? "");
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

  // Cek status sync dari backend
  Future<void> checkSyncStatus() async {
    try {
      final response = await _dio.get('/external/sync/status');
      state = state.copyWith(isSyncing: response.data['isSyncing'] as bool? ?? false);
    } catch (e) {
      // ignore
    }
  }

  // Picu sinkronisasi manual di background
  Future<void> syncAllDrugs() async {
    state = state.copyWith(isSyncing: true);
    try {
      await _dio.post('/external/sync/all');
    } catch (e) {
      state = state.copyWith(isSyncing: false);
    }
  }

  // Hapus obat berdasarkan ID
  Future<bool> deleteDrug(String drugId) async {
    try {
      await _dio.delete('/drugs/$drugId');
      state = state.copyWith(
        drugs: state.drugs.where((d) => d.id != drugId).toList(),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal menghapus obat',
      );
      return false;
    }
  }
}


final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});
