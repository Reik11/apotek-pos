import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

// Provider laporan penjualan
final salesReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/reports/sales?period=$period');
  return response.data;
});

// Provider laporan inventaris
final inventoryReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/reports/inventory');
  return response.data;
});

// Provider laporan expired
final expiryReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/reports/expiry');
  return response.data;
});

// Selected period provider
final selectedPeriodProvider = StateProvider<String>((ref) => 'monthly');
