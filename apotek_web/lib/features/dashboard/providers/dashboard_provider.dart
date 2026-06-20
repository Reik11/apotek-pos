import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// Model dashboard summary
class DashboardSummary {
  final double todayRevenue;
  final int todayTransactions;
  final int pendingOrders;
  final int lowStockCount;
  final int nearExpiryCount;
  final List<Map<String, dynamic>> salesChart;
  final List<Map<String, dynamic>> recentTransactions;

  DashboardSummary({
    required this.todayRevenue,
    required this.todayTransactions,
    required this.pendingOrders,
    required this.lowStockCount,
    required this.nearExpiryCount,
    required this.salesChart,
    required this.recentTransactions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todayRevenue: (json['today']['revenue'] as num).toDouble(),
      todayTransactions: json['today']['transactions'],
      pendingOrders: json['alerts']['pendingOrders'],
      lowStockCount: json['alerts']['lowStockCount'],
      nearExpiryCount: json['alerts']['nearExpiryCount'],
      salesChart: List<Map<String, dynamic>>.from(json['salesChart'] ?? []),
      recentTransactions:
          List<Map<String, dynamic>>.from(json['recentTransactions'] ?? []),
    );
  }
}

// Provider
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/reports/dashboard');
  return DashboardSummary.fromJson(response.data);
});

final drugAlertsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ApiClient.createDio();
  final response = await dio.get('/drugs/alerts');
  return response.data as Map<String, dynamic>? ?? {};
});
