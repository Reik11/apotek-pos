import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../ocr/screens/ocr_screen.dart';

class ApotekerHomeScreen extends ConsumerStatefulWidget {
  const ApotekerHomeScreen({super.key});

  @override
  ConsumerState<ApotekerHomeScreen> createState() => _ApotekerHomeScreenState();
}

class _ApotekerHomeScreenState extends ConsumerState<ApotekerHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ApotekPOS — Apoteker'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Di dalam AppBar actions, tambahkan sebelum IconButton logout:
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Resep',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OcrScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'Orders'),
            Tab(icon: Icon(Icons.inventory), text: 'Stok'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ApotekerDashboard(currency: currency),
          _OrdersTab(currency: currency),
          _StokTab(currency: currency),
        ],
      ),
    );
  }
}

// Tab Dashboard Apoteker
class _ApotekerDashboard extends ConsumerWidget {
  final NumberFormat currency;
  const _ApotekerDashboard({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<dynamic>(
      future: ApiClient.createDio().get('/reports/dashboard'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data;
        if (data == null) {
          return const Center(child: Text('Gagal memuat data'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Selamat Datang, Apoteker!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pantau stok dan order hari ini',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Alert cards
              _AlertCard(
                icon: Icons.pending_actions,
                title: 'Order Menunggu',
                value: '${data['alerts']['pendingOrders']}',
                color: AppTheme.warning,
                subtitle: 'Perlu diverifikasi',
              ),
              const SizedBox(height: 12),
              _AlertCard(
                icon: Icons.warning_amber,
                title: 'Stok Kritis',
                value: '${data['alerts']['lowStockCount']}',
                color: AppTheme.danger,
                subtitle: 'Obat perlu restok',
              ),
              const SizedBox(height: 12),
              _AlertCard(
                icon: Icons.event_busy,
                title: 'Hampir Expired',
                value: '${data['alerts']['nearExpiryCount']}',
                color: Colors.orange,
                subtitle: 'Dalam 30 hari ke depan',
              ),
              const SizedBox(height: 24),

              // Penjualan hari ini
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pendapatan Hari Ini',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          currency.format(data['today']['revenue']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Tab Orders
class _OrdersTab extends ConsumerWidget {
  final NumberFormat currency;
  const _OrdersTab({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<dynamic>(
      future: ApiClient.createDio().get('/orders'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.data as List? ?? [];

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('Tidak ada order'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(authProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(
                order: order,
                currency: currency,
                onUpdateStatus: (status) async {
                  await ApiClient.createDio().patch(
                    '/orders/${order['id']}/status',
                    data: {'status': status},
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Tab Stok
class _StokTab extends ConsumerWidget {
  final NumberFormat currency;
  const _StokTab({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<dynamic>(
      future: ApiClient.createDio().get('/drugs'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final drugs = snapshot.data?.data as List? ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drugs.length,
          itemBuilder: (context, index) {
            final drug = drugs[index];
            final batches = drug['batches'] as List? ?? [];
            final totalStock =
                batches.fold<int>(0, (sum, b) => sum + (b['stock'] as int));
            final isLow = totalStock <= (drug['minStock'] as int);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLow
                      ? AppTheme.danger.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLow
                          ? AppTheme.danger.withOpacity(0.1)
                          : AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: isLow ? AppTheme.danger : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          drug['category'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalStock ${drug['unit']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLow ? AppTheme.danger : AppTheme.success,
                          fontSize: 16,
                        ),
                      ),
                      if (isLow)
                        const Text(
                          'Stok Kritis!',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.danger,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Widget alert card
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget order card
class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final NumberFormat currency;
  final Function(String) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.currency,
    required this.onUpdateStatus,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String currentStatus;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order['status'];
  }

  Color get statusColor {
    switch (currentStatus) {
      case 'PENDING':
        return AppTheme.warning;
      case 'CONFIRMED':
        return AppTheme.primaryLight;
      case 'PREPARING':
        return Colors.orange;
      case 'READY':
        return AppTheme.success;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String get nextStatus {
    switch (currentStatus) {
      case 'PENDING':
        return 'CONFIRMED';
      case 'CONFIRMED':
        return 'PREPARING';
      case 'PREPARING':
        return 'READY';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header order
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.order['orderCode'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Pasien
          Text(
            'Pasien: ${widget.order['patient']?['name'] ?? '-'}',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Items
          ...items.take(2).map((item) => Text(
                '• ${item['drug']['name']} x${item['quantity']}',
                style: const TextStyle(fontSize: 13),
              )),
          if (items.length > 2)
            Text(
              '+ ${items.length - 2} item lainnya',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(height: 12),

          // Total & tombol update
          Row(
            children: [
              Text(
                widget.currency.format(widget.order['totalAmount']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (nextStatus.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    await widget.onUpdateStatus(nextStatus);
                    setState(() => currentStatus = nextStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    nextStatus == 'CONFIRMED'
                        ? 'Konfirmasi'
                        : nextStatus == 'PREPARING'
                            ? 'Siapkan'
                            : 'Tandai Siap',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
