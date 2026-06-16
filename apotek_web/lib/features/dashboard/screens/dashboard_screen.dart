import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/dashboard_provider.dart';

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
            // Header
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
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Cards ringkasan
            dashboardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.danger, size: 48),
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
              data: (summary) => GridView.count(
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
            ),

            const SizedBox(height: 32),

            // Quick actions
            const Text(
              'Akses Cepat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.point_of_sale,
                  label: 'Buka Kasir',
                  color: AppTheme.primary,
                  onTap: () => Navigator.pushNamed(context, '/kasir'),
                ),
                const SizedBox(width: 16),
                _QuickAction(
                  icon: Icons.add_box_outlined,
                  label: 'Tambah Obat',
                  color: AppTheme.success,
                  onTap: () => Navigator.pushNamed(context, '/inventory'),
                ),
                const SizedBox(width: 16),
                _QuickAction(
                  icon: Icons.bar_chart,
                  label: 'Lihat Laporan',
                  color: AppTheme.primaryLight,
                  onTap: () => Navigator.pushNamed(context, '/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget stat card gradient — "Clinical Trust" redesign
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.paddingCard,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget quick action
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
