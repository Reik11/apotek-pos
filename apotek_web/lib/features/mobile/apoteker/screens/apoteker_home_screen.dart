import 'dart:math' as math;
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
      const _PrescriptionsTab(),
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
            icon: Icon(Icons.assignment_rounded),
            label: 'Resep Masuk',
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

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final responses = await Future.wait([
      ApiClient.createDio().get('/reports/dashboard'),
      ApiClient.createDio().get('/drugs/alerts'),
    ]);
    return {
      'dashboard': responses[0].data,
      'alertsDetail': responses[1].data,
    };
  }

  void _showLowStockSheet(BuildContext context, List<dynamic> lowStock) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                SizedBox(width: 8),
                Text('Daftar Obat Stok Kritis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            if (lowStock.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada obat dengan stok kritis')))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lowStock.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = lowStock[index];
                    return ListTile(
                      title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: Text(
                        'Stok: ${item['currentStock']} (Min: ${item['minStock']})',
                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showExpiringSheet(BuildContext context, List<dynamic> nearExpiry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Obat Hampir Kadaluarsa (<90 hari)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            if (nearExpiry.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada obat hampir kadaluarsa')))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: nearExpiry.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = nearExpiry[index];
                    final batches = item['batches'] as List? ?? [];
                    final batchInfo = batches.map((b) {
                      final date = DateTime.parse(b['expiredDate']);
                      final formattedDate = DateFormat('dd MMM yyyy').format(date);
                      return 'No: ${b['batchNumber']} (Stok: ${b['stock']}, Exp: $formattedDate)';
                    }).join('\n');

                    return ListTile(
                      title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(batchInfo, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDashboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final responseData = snapshot.data;
        if (responseData == null) {
          return const Center(child: Text('Gagal memuat data'));
        }

        final data = responseData['dashboard'];
        final alertsDetail = responseData['alertsDetail'];
        final lowStockList = alertsDetail?['lowStock'] as List? ?? [];
        final nearExpiryList = alertsDetail?['nearExpiry'] as List? ?? [];

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
                'Perhatian Utama (Ketuk untuk Detail)',
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
                onTap: () => _showLowStockSheet(context, lowStockList),
              ),
              const SizedBox(height: 16),
              _AlertCard(
                icon: Icons.event_busy_rounded,
                title: 'Hampir Expired',
                value: '${data['alerts']['nearExpiryCount']}',
                color: Colors.orange,
                subtitle: 'Dalam 90 hari ke depan',
                onTap: () => _showExpiringSheet(context, nearExpiryList),
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

// Tab Resep Masuk (Apoteker Verifikasi)
class _PrescriptionsTab extends StatefulWidget {
  const _PrescriptionsTab();

  @override
  State<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<_PrescriptionsTab> {
  List<dynamic> prescriptions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiClient.createDio().get('/prescriptions');
      setState(() {
        prescriptions = response.data as List? ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _verifyPrescription(String id, String status, {List<Map<String, dynamic>>? prescribedDrugs}) async {
    try {
      await ApiClient.createDio().patch(
        '/prescriptions/$id/verify',
        data: {
          'status': status,
          if (prescribedDrugs != null) 'prescribedDrugs': prescribedDrugs,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resep berhasil ${status == 'VERIFIED' ? 'disetujui' : 'ditolak'}'),
            backgroundColor: status == 'VERIFIED' ? AppTheme.success : AppTheme.danger,
          ),
        );
      }
      _loadPrescriptions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal verifikasi resep: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showPrescribeDialog(BuildContext context, Map<String, dynamic> prescription) async {
    final id = prescription['id'];
    final patient = prescription['patient'] ?? {};
    
    List<dynamic> allDrugs = [];
    List<dynamic> filteredDrugs = [];
    List<Map<String, dynamic>> selectedDrugs = [];
    bool isDialogLoading = true;

    // OCR variables
    String ocrRawText = '';
    List<dynamic> ocrDetectedDrugs = [];
    bool isOcrLoading = true;

    // Fetch drugs
    try {
      final res = await ApiClient.createDio().get('/drugs');
      allDrugs = res.data as List? ?? [];
      filteredDrugs = List.from(allDrugs);
      isDialogLoading = false;
    } catch (e) {
      isDialogLoading = false;
    }

    // Kalkulasi Usia & BSA (Body Surface Area) jika data fisik lengkap
    String ageText = '—';
    double? bsa;
    if (patient['birthDate'] != null) {
      final birth = DateTime.tryParse(patient['birthDate']);
      if (birth != null) {
        final age = DateTime.now().difference(birth).inDays ~/ 365;
        ageText = '$age tahun';
      }
    }
    
    final weight = patient['weight'] != null ? (patient['weight'] as num).toDouble() : null;
    final height = patient['height'] != null ? (patient['height'] as num).toDouble() : null;
    
    if (weight != null && height != null) {
      // BSA using Mosteller formula: sqrt((W * H) / 3600)
      bsa = math.sqrt((weight * height) / 3600.0);
    }

    if (!context.mounted) return;

    // Pemicu OCR otomatis di latar belakang saat dialog dibuka
    void runOcrScan(StateSetter setDialogState) async {
      try {
        final res = await ApiClient.createDio().post(
          '/external/ocr-prescription-url',
          data: {'imageUrl': prescription['imageUrl']},
        );
        final rawText = res.data['rawText'] ?? '';
        final drugsList = res.data['drugs'] as List? ?? [];
        
        // Cari padanan obat lokal apotek berdasarkan nama terdeteksi
        for (var ocrDrug in drugsList) {
          final detectedName = ocrDrug['detectedName'].toString().toLowerCase();
          final matchedLocal = allDrugs.firstWhere(
            (d) => d['name'].toString().toLowerCase().contains(detectedName) ||
                   (d['genericName'] != null && d['genericName'].toString().toLowerCase().contains(detectedName)),
            orElse: () => null,
          );
          if (matchedLocal != null) {
            ocrDrug['localDrugId'] = matchedLocal['id'];
            ocrDrug['localDrugName'] = matchedLocal['name'];
            ocrDrug['localDrugPrice'] = matchedLocal['sellPrice'];
          }
        }

        setDialogState(() {
          ocrRawText = rawText;
          ocrDetectedDrugs = drugsList;
          isOcrLoading = false;
        });
      } catch (e) {
        setDialogState(() {
          ocrRawText = 'Gagal memindai resep secara otomatis.';
          isOcrLoading = false;
        });
      }
    }

    bool hasTriggeredOcr = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isDialogLoading) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          // Picu scan sekali saja saat dialog dirender pertama kali
          if (!hasTriggeredOcr) {
            hasTriggeredOcr = true;
            runOcrScan(setDialogState);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppTheme.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verifikasi Klinis & Pembuatan Tagihan Resep', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Pasien: ${patient['name'] ?? '-'} (${patient['email'] ?? '-'})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 850,
              height: 600,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SEBELAH KIRI: PANEL INFORMASI MEDIS PASIEN ──
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RESEP DOKTER ASLI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  prescription['imageUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 32),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('DATA KLINIS PASIEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary, letterSpacing: 0.5)),
                            const Divider(height: 16),
                            
                            _medDetailRow('Usia', ageText),
                            _medDetailRow('Berat Badan', weight != null ? '$weight kg' : '—'),
                            _medDetailRow('Tinggi Badan', height != null ? '$height cm' : '—'),
                            _medDetailRow('BSA (Luas Permukaan)', bsa != null ? '${bsa.toStringAsFixed(2)} m²' : '—'),
                            _medDetailRow('Jenis Kelamin', patient['gender'] ?? '—'),
                            
                            const SizedBox(height: 12),
                            const Text('KONDISI KHUSUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (patient['isPregnant'] == true)
                                  _badgeWidget('Sedang Hamil', AppTheme.danger),
                                if (patient['isBreastfeeding'] == true)
                                  _badgeWidget('Menyusui', Colors.orange),
                                if (patient['isPregnant'] != true && patient['isBreastfeeding'] != true)
                                  const Text('Tidak ada kondisi khusus', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            const Text('RIWAYAT MEDIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),
                            _bulletDetailRow('Alergi Obat', patient['allergies']),
                            _bulletDetailRow('Penyakit Kronis', patient['chronicDiseases']),
                            _bulletDetailRow('Obat Rutin', patient['currentMedications']),
                            
                            const SizedBox(height: 12),
                            const Text('FUNGSI ORGAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),
                            _medDetailRow('Fungsi Ginjal', patient['kidneyFunction'] ?? 'Normal'),
                            _medDetailRow('Fungsi Hati', patient['liverFunction'] ?? 'Normal'),
                            const SizedBox(height: 16),
                            const Text('REKOMENDASI HASIL SCAN AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success, letterSpacing: 0.5)),
                            const Divider(height: 16),
                            if (isOcrLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('Memindai tulisan resep dokter...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              )
                            else if (ocrDetectedDrugs.isEmpty)
                              const Text('Tidak ada obat terbaca otomatis.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Ketuk rekomendasi obat di bawah untuk memasukkan resep:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  ...ocrDetectedDrugs.map((ocrDrug) {
                                    final localName = ocrDrug['localDrugName'];
                                    final localId = ocrDrug['localDrugId'];
                                    final detected = ocrDrug['detectedName'];
                                    
                                    if (localId == null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text('• $detected (Obat tidak ada di apotek)', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                                      );
                                    }
                                    
                                    final added = selectedDrugs.any((sd) => sd['drugId'] == localId);
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: InkWell(
                                        onTap: added ? null : () {
                                          setDialogState(() {
                                            selectedDrugs.add({
                                              'drugId': localId,
                                              'name': localName,
                                              'sellPrice': ocrDrug['localDrugPrice'],
                                              'quantity': 1,
                                              'notes': '',
                                            });
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Icon(added ? Icons.check_circle : Icons.add_circle, color: added ? AppTheme.success : AppTheme.primary, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '$detected -> $localName',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: added ? Colors.grey : AppTheme.textPrimary,
                                                  decoration: added ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                          ],

                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // ── SEBELAH TENGAH: PENCARIAN OBAT APOTEK ──
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PENCARIAN OBAT APOTEK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Cari obat...',
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val.isEmpty) {
                                filteredDrugs = List.from(allDrugs);
                              } else {
                                filteredDrugs = allDrugs
                                    .where((d) =>
                                        d['name'].toString().toLowerCase().contains(val.toLowerCase()) ||
                                        (d['genericName'] != null && d['genericName'].toString().toLowerCase().contains(val.toLowerCase())))
                                    .toList();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredDrugs.length,
                            itemBuilder: (c, idx) {
                              final drug = filteredDrugs[idx];
                              final exists = selectedDrugs.any((sd) => sd['drugId'] == drug['id']);
                              return ListTile(
                                title: Text(drug['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: Text('${drug['category']} - Rp ${drug['sellPrice']}', style: const TextStyle(fontSize: 10)),
                                trailing: exists
                                    ? const Icon(Icons.check_circle, color: AppTheme.success, size: 18)
                                    : const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 18),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onTap: () {
                                  setDialogState(() {
                                    if (!exists) {
                                      selectedDrugs.add({
                                        'drugId': drug['id'],
                                        'name': drug['name'],
                                        'sellPrice': drug['sellPrice'],
                                        'quantity': 1,
                                        'notes': '', // Tempat aturan pakai / Signa
                                      });
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // ── SEBELAH KANAN: DAFTAR OBAT TERPILIH & SIGNA ──
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OBAT & DOSIS RESEP (SIGNA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: selectedDrugs.isEmpty
                              ? const Center(child: Text('Belum ada obat terpilih', style: TextStyle(fontSize: 12, color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: selectedDrugs.length,
                                  itemBuilder: (c, idx) {
                                    final sd = selectedDrugs[idx];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(sd['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    selectedDrugs.removeAt(idx);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Jumlah Qty:', style: TextStyle(fontSize: 11)),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.danger),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        if (sd['quantity'] > 1) sd['quantity']--;
                                                      });
                                                    },
                                                  ),
                                                  Text('${sd['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.success),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        sd['quantity']++;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Text('Aturan Pakai / Signa:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 4),
                                          TextField(
                                            style: const TextStyle(fontSize: 12),
                                            decoration: const InputDecoration(
                                              hintText: 'Contoh: 3x sehari 1 tablet setelah makan',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              sd['notes'] = val;
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                onPressed: selectedDrugs.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        // Hitung konversi ke order
                        try {
                          await ApiClient.createDio().post(
                            '/prescriptions/$id/convert-to-order',
                            data: {
                              'items': selectedDrugs.map((d) => {
                                'drugId': d['drugId'],
                                'quantity': d['quantity'],
                                'notes': d['notes'],
                              }).toList(),
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Resep berhasil diverifikasi & tagihan pasien terbuat!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                          _loadPrescriptions();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal membuat tagihan: $e'),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Verifikasi & Buat Tagihan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _medDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _bulletDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value != null && value.isNotEmpty ? '• $value' : '• Tidak ada riwayat.',
            style: TextStyle(
              fontSize: 12,
              color: value != null && value.isNotEmpty ? AppTheme.textPrimary : Colors.grey,
              fontStyle: value != null && value.isNotEmpty ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeWidget(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    
    if (prescriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada resep masuk', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Resep yang diupload pasien akan muncul di sini', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: prescriptions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = prescriptions[index];
          final patient = item['patient'] ?? {};
          final notes = item['notes'] ?? '';
          final status = item['status'] as String? ?? 'PENDING';
          final date = DateTime.parse(item['createdAt']);
          final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);

          Color statusColor = AppTheme.warning;
          String statusText = 'Pending';
          if (status == 'VERIFIED') {
            statusColor = AppTheme.success;
            statusText = 'Disetujui';
          } else if (status == 'REJECTED') {
            statusColor = AppTheme.danger;
            statusText = 'Ditolak';
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      patient['name'] ?? 'Pasien Umum',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                Text(
                  patient['email'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tanggal: $formattedDate',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Divider(height: 24),
                
                // Prescription image thumbnail & notes
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // View Image button
                    GestureDetector(
                      onTap: () {
                        // Open full screen image dialog
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                InteractiveViewer(
                                  child: Image.network(item['imageUrl']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Catatan Pasien:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            notes.isNotEmpty ? notes : 'Tidak ada catatan.',
                            style: TextStyle(
                              fontSize: 13,
                              color: notes.isNotEmpty ? AppTheme.textPrimary : Colors.grey,
                              fontStyle: notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (status == 'PENDING') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.danger),
                          foregroundColor: AppTheme.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _verifyPrescription(item['id'], 'REJECTED'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Tolak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showPrescribeDialog(context, item),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Setujui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String subtitle;
  final VoidCallback? onTap;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
