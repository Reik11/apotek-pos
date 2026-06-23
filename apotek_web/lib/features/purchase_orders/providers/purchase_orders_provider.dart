import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class PurchaseOrdersState {
  final List<Map<String, dynamic>> purchaseOrders;
  final bool isLoading;
  final String? error;

  PurchaseOrdersState({this.purchaseOrders = const [], this.isLoading = false, this.error});

  PurchaseOrdersState copyWith({
    List<Map<String, dynamic>>? purchaseOrders,
    bool? isLoading,
    String? error,
  }) =>
      PurchaseOrdersState(
        purchaseOrders: purchaseOrders ?? this.purchaseOrders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class PurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> {
  final Dio _dio = ApiClient.createDio();

  PurchaseOrdersNotifier() : super(PurchaseOrdersState()) {
    loadPurchaseOrders();
  }

  Future<void> loadPurchaseOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/purchase-orders');
      final purchaseOrders = List<Map<String, dynamic>>.from(response.data);
      state = state.copyWith(purchaseOrders: purchaseOrders, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat data Purchase Order',
      );
    }
  }

  Future<bool> createPurchaseOrder(Map<String, dynamic> data) async {
    try {
      await _dio.post('/purchase-orders', data: data);
      await loadPurchaseOrders();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal membuat Purchase Order',
      );
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status, List<Map<String, dynamic>>? receiveDetails) async {
    try {
      final body = {
        'status': status,
        if (receiveDetails != null) 'receiveDetails': receiveDetails,
      };
      await _dio.patch('/purchase-orders/$id/status', data: body);
      await loadPurchaseOrders();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data['message'] ?? 'Gagal memperbarui status Purchase Order',
      );
      return false;
    }
  }
}

final purchaseOrdersProvider =
    StateNotifierProvider<PurchaseOrdersNotifier, PurchaseOrdersState>((ref) => PurchaseOrdersNotifier());
