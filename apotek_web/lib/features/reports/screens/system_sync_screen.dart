import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/sync_provider.dart';
import '../../../core/api/api_client.dart';

class SystemSyncScreen extends ConsumerStatefulWidget {
  const SystemSyncScreen({super.key});

  @override
  ConsumerState<SystemSyncScreen> createState() => _SystemSyncScreenState();
}

class _SystemSyncScreenState extends ConsumerState<SystemSyncScreen> {
  bool _isSyncingDrugs = false;
  bool _isSyncingEpidemiology = false;

  Future<void> _triggerSync(String category) async {
    setState(() {
      if (category == 'drugs') _isSyncingDrugs = true;
      if (category == 'epidemiology') _isSyncingEpidemiology = true;
    });

    try {
      final dio = ApiClient.createDio();
      final response = await dio.post('/external/sync-trigger', data: {
        'category': category,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(response.data['message'] ?? 'Sinkronisasi berhasil dipicu!'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Refresh sync logs after a short delay
      await Future.delayed(const Duration(seconds: 2));
      ref.invalidate(syncLogsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Gagal memicu sinkronisasi: $e'),
              ],
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (category == 'drugs') _isSyncingDrugs = false;
          if (category == 'epidemiology') _isSyncingEpidemiology = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncLogsAsync = ref.watch(syncLogsProvider);

    return MainLayout(
      currentRoute: '/system-sync',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header =====
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sinkronisasi Sistem',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Kelola penarikan data medis dan tren kesehatan eksternal ke database lokal.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ===== TRIGGER CONTROL PANEL =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTriggerCard(
                    title: 'Sinkronisasi Data Obat',
                    description: 'Mengunduh data klasifikasi obat, zat aktif, efek samping, dan indikasi penanganan dari database openFDA.',
                    buttonLabel: 'Sync Data Obat',
                    icon: Icons.medication_liquid_rounded,
                    isLoading: _isSyncingDrugs,
                    onPressed: () => _triggerSync('drugs'),
                    gradient: AppTheme.cardGradient2,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildTriggerCard(
                    title: 'Sinkronisasi Tren Penyakit',
                    description: 'Mengunduh statistik epidemiologi nasional (TBC, Malaria, Demam Berdarah) terbaru di Indonesia dari WHO GHO.',
                    buttonLabel: 'Sync Tren Penyakit',
                    icon: Icons.health_and_safety_rounded,
                    isLoading: _isSyncingEpidemiology,
                    onPressed: () => _triggerSync('epidemiology'),
                    gradient: AppTheme.cardGradient1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ===== LOG LIST TABLE =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadowSubtle,
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Riwayat Aktivitas Sinkronisasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Status pemicu berkala dan penarikan data secara manual.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(syncLogsProvider),
                        tooltip: 'Segarkan Riwayat',
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  syncLogsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('Gagal memuat log: $err', style: const TextStyle(color: AppTheme.danger)),
                      ),
                    ),
                    data: (logs) {
                      if (logs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'Belum ada riwayat aktivitas sinkronisasi.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 32,
                          columns: const [
                            DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Pemicu', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Waktu Mulai', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Waktu Selesai', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Data Diambil', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: logs.map<DataRow>((log) {
                            final category = log['category'] ?? '-';
                            final triggeredBy = log['triggeredBy'] ?? 'SYSTEM';
                            
                            final startedAt = log['startedAt'] != null
                                ? DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(log['startedAt']))
                                : '-';
                            final completedAt = log['completedAt'] != null
                                ? DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(log['completedAt']))
                                : '-';
                                
                            final count = log['scrapedItemsCount'] ?? 0;
                            final status = log['status'] ?? 'IN_PROGRESS';
                            
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Icon(
                                        category == 'DRUGS' ? Icons.medication_rounded : Icons.trending_up_rounded,
                                        size: 16,
                                        color: category == 'DRUGS' ? AppTheme.primary : AppTheme.success,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(category),
                                    ],
                                  ),
                                ),
                                DataCell(Text(triggeredBy)),
                                DataCell(Text(startedAt)),
                                DataCell(Text(completedAt)),
                                DataCell(Text('$count item')),
                                DataCell(_buildStatusBadge(status)),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerCard({
    required String title,
    required String description,
    required String buttonLabel,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = 'PROSES';
    
    if (status == 'SUCCESS') {
      color = AppTheme.success;
      label = 'SUKSES';
    } else if (status == 'FAILED') {
      color = AppTheme.danger;
      label = 'GAGAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
