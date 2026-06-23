import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return MainLayout(
      currentRoute: '/dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh data',
                  onPressed: () => ref.refresh(dashboardProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ===== STAT CARDS =====
            dashboardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 8),
                    Text('Gagal memuat data: $err'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.refresh(dashboardProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _StatCard(
                        title: 'Pendapatan Hari Ini',
                        value: currency.format(summary.todayRevenue),
                        icon: Icons.attach_money_rounded,
                        gradient: AppTheme.cardGradient1,
                      ),
                      _StatCard(
                        title: 'Transaksi Hari Ini',
                        value: '${summary.todayTransactions} transaksi',
                        icon: Icons.receipt_long_rounded,
                        gradient: AppTheme.cardGradient2,
                      ),
                      _StatCard(
                        title: 'Stok Kritis',
                        value: '${summary.lowStockCount} obat',
                        icon: Icons.warning_amber_rounded,
                        gradient: AppTheme.cardGradient3,
                      ),
                      _StatCard(
                        title: 'Hampir Kadaluarsa',
                        value: '${summary.nearExpiryCount} batch',
                        icon: Icons.event_busy_rounded,
                        gradient: AppTheme.cardGradient4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== SALES CHART + QUICK ACTIONS ROW =====
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sales chart
                      Expanded(
                        flex: 3,
                        child: _SalesChart(salesChart: summary.salesChart, currency: currency),
                      ),
                      const SizedBox(width: 16),
                      // Quick actions
                      Expanded(
                        flex: 2,
                        child: _buildQuickActions(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== RECENT TRANSACTIONS =====
                  _RecentTransactions(transactions: summary.recentTransactions, currency: currency),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ===== ALERTS SECTION =====
            _buildWebAlertsSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QAData(Icons.point_of_sale_rounded, 'Buka Kasir', AppTheme.primary, '/kasir'),
      _QAData(Icons.inventory_2_rounded, 'Inventaris', AppTheme.success, '/inventory'),
      _QAData(Icons.bar_chart_rounded, 'Laporan', AppTheme.primaryLight, '/reports'),
      _QAData(Icons.people_rounded, 'Pengguna', const Color(0xFFD97706), '/users'),
      _QAData(Icons.person_rounded, 'Profil Saya', const Color(0xFF7C3AED), '/profile'),
      _QAData(Icons.description_rounded, 'Laporan User', const Color(0xFF0891B2), '/admin-reports'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSubtle,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akses Cepat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: actions.map((a) => _QuickActionTile(data: a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAlertsSection(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(drugAlertsProvider);

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox(),
      data: (data) {
        final lowStock = List<Map<String, dynamic>>.from(data['lowStock'] ?? []);
        final nearExpiry = List<Map<String, dynamic>>.from(data['nearExpiry'] ?? []);

        if (lowStock.isEmpty && nearExpiry.isEmpty) return const SizedBox();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Low Stock
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowSubtle,
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                        SizedBox(width: 8),
                        Text('Stok Kritis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    if (lowStock.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Tidak ada obat dengan stok kritis.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lowStock.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final item = lowStock[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Text(
                              'Stok: ${item['currentStock']} (Min: ${item['minStock']})',
                              style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Near Expiry
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowSubtle,
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_busy_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Hampir Kadaluarsa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    if (nearExpiry.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Tidak ada obat hampir kadaluarsa.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: nearExpiry.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final item = nearExpiry[i];
                          final batches = item['batches'] as List? ?? [];
                          final batchInfo = batches.map((b) {
                            final exp = b['expiredDate'] != null
                                ? DateFormat('dd/MM/yy').format(DateTime.parse(b['expiredDate']))
                                : '-';
                            return 'Exp: $exp (Stok: ${b['stock']})';
                          }).join(', ');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(batchInfo, style: const TextStyle(fontSize: 11, color: Colors.orange)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===== STAT CARD =====
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== SALES CHART =====
class _SalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> salesChart;
  final NumberFormat currency;

  const _SalesChart({required this.salesChart, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = salesChart.fold<double>(
      1.0,
      (max, d) => (d['revenue'] as num).toDouble() > max ? (d['revenue'] as num).toDouble() : max,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSubtle,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik Pendapatan 7 Hari Terakhir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: salesChart.isEmpty
                ? const Center(child: Text('Belum ada data transaksi', style: TextStyle(color: Colors.grey)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: salesChart.map((day) {
                      final revenue = (day['revenue'] as num).toDouble();
                      final ratio = revenue / maxRevenue;
                      final date = day['date'] as String;
                      final label = date.length >= 5 ? date.substring(5) : date;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (revenue > 0)
                                Text(
                                  'Rp${(revenue / 1000).toStringAsFixed(0)}k',
                                  style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: ratio * 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primary.withValues(alpha: 0.7), AppTheme.primary],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===== RECENT TRANSACTIONS =====
class _RecentTransactions extends ConsumerWidget {
  final List<Map<String, dynamic>> transactions;
  final NumberFormat currency;

  const _RecentTransactions({required this.transactions, required this.currency});

  void _confirmVoid(BuildContext context, WidgetRef ref, String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Void', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan transaksi ini? '
          'Tindakan ini akan mengembalikan stok obat ke batch semula dan mengubah status transaksi menjadi VOID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = ApiClient.createDio();
                await dio.patch('/transactions/$transactionId/void');
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil dibatalkan (void)'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  // Refresh data
                  ref.refresh(dashboardProvider);
                  ref.refresh(drugAlertsProvider);
                  ref.read(inventoryProvider.notifier).loadDrugs();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membatalkan transaksi: $e'),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Void'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userRole = authState.user?.role;
    final isAdmin = userRole == 'ADMIN' || userRole == 'SUPER_ADMIN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSubtle,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Transaksi Terbaru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada transaksi hari ini', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2), // ID
                1: FlexColumnWidth(2),   // Kasir
                2: FlexColumnWidth(2),   // Total
                3: FlexColumnWidth(1.2), // Metode
                4: FlexColumnWidth(1.8), // Waktu
                5: FlexColumnWidth(1.2), // Status
                6: FlexColumnWidth(1.2), // Aksi
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: ['ID', 'Kasir', 'Total', 'Metode', 'Waktu', 'Status', 'Aksi']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Text(h,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ))
                      .toList(),
                ),
                ...transactions.map((tx) {
                  final id = (tx['id'] as String? ?? '').substring(0, 8);
                  final cashier = tx['cashierName'] as String? ?? '-';
                  final total = (tx['totalAmount'] as num).toDouble();
                  final method = tx['paymentMethod'] as String? ?? '-';
                  final createdAt = tx['createdAt'] != null
                      ? DateFormat('dd/MM HH:mm').format(DateTime.parse(tx['createdAt']).toLocal())
                      : '-';
                  
                  final status = tx['status'] as String? ?? 'COMPLETED';
                  final Color statusColor;
                  final String statusLabel;
                  if (status == 'CANCELLED') {
                    statusColor = AppTheme.danger;
                    statusLabel = 'VOID';
                  } else if (status == 'REFUNDED') {
                    statusColor = AppTheme.warning;
                    statusLabel = 'REFUND';
                  } else {
                    statusColor = AppTheme.success;
                    statusLabel = 'SUKSES';
                  }

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#$id', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                            if (tx['notes'] != null && (tx['notes'] as String).trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                tx['notes'],
                                style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Text(cashier, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Text(currency.format(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(method, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Text(createdAt, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: isAdmin && status == 'COMPLETED'
                            ? TextButton.icon(
                                onPressed: () => _confirmVoid(context, ref, tx['id']),
                                icon: const Icon(Icons.cancel_outlined, size: 14, color: AppTheme.danger),
                                label: const Text('Void', style: TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                            : const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

// ===== QUICK ACTION TILE =====
class _QAData {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  _QAData(this.icon, this.label, this.color, this.route);
}

class _QuickActionTile extends StatelessWidget {
  final _QAData data;
  const _QuickActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(data.route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: data.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: data.color, size: 26),
            const SizedBox(height: 6),
            Text(
              data.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: data.color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
