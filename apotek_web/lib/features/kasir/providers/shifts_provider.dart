import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ShiftsState {
  final Map<String, dynamic>? activeShift;
  final bool isLoading;
  final String? error;

  ShiftsState({this.activeShift, this.isLoading = false, this.error});

  ShiftsState copyWith({
    Map<String, dynamic>? activeShift,
    bool? isLoading,
    String? error,
    bool clearActiveShift = false,
  }) =>
      ShiftsState(
        activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ShiftsNotifier extends StateNotifier<ShiftsState> {
  final Dio _dio = ApiClient.createDio();

  ShiftsNotifier() : super(ShiftsState()) {
    checkActiveShift();
  }

  Future<void> checkActiveShift() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/shifts/active');
      if (response.data != null && response.data != '') {
        state = state.copyWith(activeShift: Map<String, dynamic>.from(response.data), isLoading: false);
      } else {
        state = state.copyWith(clearActiveShift: true, isLoading: false);
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat status shift kasir',
      );
    }
  }

  Future<bool> openShift(double startBalance, [String? notes]) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/shifts/open', data: {
        'startBalance': startBalance,
        if (notes != null) 'notes': notes,
      });
      state = state.copyWith(activeShift: Map<String, dynamic>.from(response.data), isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal membuka shift kasir',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> closeShift(double endBalance, [String? notes]) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/shifts/close', data: {
        'endBalance': endBalance,
        if (notes != null) 'notes': notes,
      });
      final closedShift = Map<String, dynamic>.from(response.data);
      state = state.copyWith(clearActiveShift: true, isLoading: false);
      return closedShift;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal menutup shift kasir',
      );
      return null;
    }
  }
}

final shiftsProvider =
    StateNotifierProvider<ShiftsNotifier, ShiftsState>((ref) => ShiftsNotifier());
