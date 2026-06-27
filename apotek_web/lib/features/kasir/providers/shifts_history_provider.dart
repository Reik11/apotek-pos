import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ShiftsHistoryState {
  final List<Map<String, dynamic>> shifts;
  final bool isLoading;
  final String? error;

  ShiftsHistoryState({
    this.shifts = const [],
    this.isLoading = false,
    this.error,
  });

  ShiftsHistoryState copyWith({
    List<Map<String, dynamic>>? shifts,
    bool? isLoading,
    String? error,
  }) =>
      ShiftsHistoryState(
        shifts: shifts ?? this.shifts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ShiftsHistoryNotifier extends StateNotifier<ShiftsHistoryState> {
  final Dio _dio = ApiClient.createDio();

  ShiftsHistoryNotifier() : super(ShiftsHistoryState()) {
    loadShiftsHistory();
  }

  Future<void> loadShiftsHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/shifts');
      final shifts = List<Map<String, dynamic>>.from(response.data);
      state = state.copyWith(shifts: shifts, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] ?? 'Gagal memuat riwayat shift kasir',
      );
    }
  }
}

final shiftsHistoryProvider =
    StateNotifierProvider<ShiftsHistoryNotifier, ShiftsHistoryState>((ref) {
  return ShiftsHistoryNotifier();
});
