import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// Provider log sinkronisasi
final syncLogsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/external/sync-logs');
  return response.data as List? ?? [];
});

// Provider tren epidemiologi nasional
final epidemiologyTrendsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/external/trends');
  return response.data as List? ?? [];
});

// Provider obat paling laris
final topSellingDrugsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/external/top-selling');
  return response.data as List? ?? [];
});
