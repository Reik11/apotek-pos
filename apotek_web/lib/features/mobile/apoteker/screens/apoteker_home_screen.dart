import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../ocr/screens/ocr_screen.dart';
import '../../profile/profile_screen.dart';

class ApotekerHomeScreen extends ConsumerStatefulWidget {
  const ApotekerHomeScreen({super.key});

  @override
  ConsumerState<ApotekerHomeScreen> createState() => _ApotekerHomeScreenState();
}

class _ApotekerHomeScreenState extends ConsumerState<ApotekerHomeScreen> {
  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    
    final List<Widget> pages = [
      _ApotekerDashboard(currency: currency),
      _OrdersTab(currency: currency),
      _StokTab(currency: currency),
      const ProfileScreen(isFromBottomNav: true),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Background luar untuk Web
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            color: AppTheme.background,
            child: Column(
              children: [
                _buildHeader(user?.name ?? 'Apoteker'),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: pages[_currentIndex],
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
      // Floating Action Button khusus untuk tab pertama jika ingin fitur OCR cepat
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OcrScreen()),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.document_scanner, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildHeader(String userName) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $userName 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Siap melayani hari ini?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Stok Obat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profil',
          ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Penjualan hari ini (Modern Card)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payments_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pendapatan Masuk',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          currency.format(data['today']['revenue']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Perhatian Utama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Alert cards
              _AlertCard(
                icon: Icons.pending_actions_rounded,
                title: 'Order Menunggu',
                value: '${data['alerts']['pendingOrders']}',
                color: AppTheme.warning,
                subtitle: 'Perlu verifikasi Anda',
              ),
              const SizedBox(height: 16),
              _AlertCard(
                icon: Icons.warning_amber_rounded,
                title: 'Stok Kritis',
                value: '${data['alerts']['lowStockCount']}',
                color: AppTheme.danger,
                subtitle: 'Obat segera habis',
              ),
              const SizedBox(height: 16),
              _AlertCard(
                icon: Icons.event_busy_rounded,
                title: 'Hampir Expired',
                value: '${data['alerts']['nearExpiryCount']}',
                color: Colors.orange,
                subtitle: 'Dalam 30 hari ke depan',
              ),
              const SizedBox(height: 80), // padding untuk FAB
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Belum ada pesanan masuk', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(authProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
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
          padding: const EdgeInsets.all(20),
          itemCount: drugs.length,
          itemBuilder: (context, index) {
            final drug = drugs[index];
            final batches = drug['batches'] as List? ?? [];
            final totalStock =
                batches.fold<int>(0, (sum, b) => sum + (b['stock'] as int));
            final isLow = totalStock <= (drug['minStock'] as int);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLow
                      ? AppTheme.danger.withOpacity(0.3)
                      : Colors.grey.shade100,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLow
                          ? AppTheme.danger.withOpacity(0.1)
                          : AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: isLow ? AppTheme.danger : AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                          fontSize: 18,
                        ),
                      ),
                      if (isLow)
                        const Text(
                          'Stok Kritis!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

// Widget alert card modern
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget order card modern
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header order
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kode Order',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      widget.order['orderCode'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          // Pasien
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${widget.order['patient']?['name'] ?? 'Pasien Umum'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${item['drug']['name']} x${item['quantity']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                )),
                if (items.length > 2)
                  Text(
                    '+ ${items.length - 2} item lainnya',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total & tombol update
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Tagihan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text(
                    widget.currency.format(widget.order['totalAmount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (nextStatus.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    await widget.onUpdateStatus(nextStatus);
                    setState(() => currentStatus = nextStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    nextStatus == 'CONFIRMED'
                        ? 'Konfirmasi'
                        : nextStatus == 'PREPARING'
                            ? 'Siapkan'
                            : 'Tandai Siap',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
