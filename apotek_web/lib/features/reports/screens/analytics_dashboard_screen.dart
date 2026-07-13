import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/sync_provider.dart';
import '../providers/reports_provider.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(epidemiologyTrendsProvider);
    final topSellingAsync = ref.watch(topSellingDrugsProvider);
    final recallsAsync = ref.watch(fdaRecallsProvider);

    return MainLayout(
      currentRoute: '/analytics',
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
                  'Analisis Tren & Keputusan',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Korelasi tren penyakit nasional dengan penjualan apotek untuk rekomendasi restock cerdas.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ===== TOP CARDS ROW =====
            Row(
              children: [
                _buildInfoCard(
                  title: 'Rasio Penjualan Lokal',
                  value: '8 Utama',
                  subtitle: 'Obat terlaris terpetakan',
                  icon: Icons.store_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 16),
                _buildInfoCard(
                  title: 'Wilayah Terpantau',
                  value: 'Indonesia (IDN)',
                  subtitle: 'Sumber data: WHO GHO',
                  icon: Icons.public_rounded,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 16),
                _buildInfoCard(
                  title: 'Akurasi Rekomendasi',
                  value: 'Prediktif',
                  subtitle: 'Berdasarkan korelasi historis',
                  icon: Icons.auto_awesome_rounded,
                  color: AppTheme.accent,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ===== SMART ADVISORY BOX =====
            trendsAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (trends) => _buildSmartAdvisoryCard(trends),
            ),
            const SizedBox(height: 24),

            // ===== GRAPH ROW =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Grafik Tren Penyakit Nasional
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 400,
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
                          'Tren Kasus Penyakit Nasional (Indonesia)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const Text(
                          'Data historis tahunan bersumber dari WHO (dalam ribuan kasus)',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: trendsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Gagal memuat tren penyakit: $e')),
                            data: (trends) {
                              if (trends.isEmpty) {
                                return const Center(child: Text('Data tren kosong. Silakan lakukan sinkronisasi manual.'));
                              }
                              return _buildDiseaseTrendLineChart(trends);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 2. Grafik Penjualan Terlaris Lokal
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 400,
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
                          'Obat Terlaris Apotek (Lokal)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const Text(
                          '8 obat dengan volume penjualan terbanyak saat ini',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: topSellingAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Gagal memuat data penjualan: $e')),
                            data: (items) {
                              if (items.isEmpty) {
                                return const Center(
                                  child: Text('Belum ada data penjualan atau transaksi di outlet Anda.', textAlign: TextAlign.center),
                                );
                              }
                              return _buildTopSellingBarChart(items);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ===== GLOBAL SAFETY TRENDS ROW (2nd External Visualization) =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    height: 380,
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
                          'Tingkat Keamanan Obat Global (FDA Recall)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const Text(
                          'Distribusi bahaya keamanan obat berdasarkan klasifikasi kelas openFDA (Proporsi % & Volume)',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: recallsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Gagal memuat recalls: $e')),
                            data: (recalls) {
                              if (recalls.isEmpty) {
                                return const Center(
                                  child: Text('Tidak ada data recall obat FDA terbaru.', style: TextStyle(color: AppTheme.textSecondary)),
                                );
                              }
                              return _buildFdaRecallPieChart(recalls);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadowSubtle,
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAdvisoryCard(List<dynamic> trends) {
    // Cari status tren DBD (Dengue) & Malaria
    // Analisis sederhana: Bandingkan data tahun terakhir vs sebelumnya
    final dengueData = trends.where((t) => t['diseaseCategory'] == 'DENGUE').toList()
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
    
    final malariaData = trends.where((t) => t['diseaseCategory'] == 'MALARIA').toList()
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

    bool isDengueRising = false;
    bool isMalariaRising = false;
    
    if (dengueData.length >= 2) {
      isDengueRising = dengueData[dengueData.length - 1]['value'] > dengueData[dengueData.length - 2]['value'];
    }
    if (malariaData.length >= 2) {
      isMalariaRising = malariaData[malariaData.length - 1]['value'] > malariaData[malariaData.length - 2]['value'];
    }

    String adviceTitle = 'Rekomendasi Stok Normal';
    String adviceText = 'Penjualan lokal dan tren kesehatan nasional stabil. Pertahankan stok obat sesuai minStock yang terdaftar.';
    Color cardColor = AppTheme.success;
    IconData cardIcon = Icons.check_circle_rounded;

    if (isDengueRising && isMalariaRising) {
      adviceTitle = 'PERINGATAN RESTOCK: Kasus DBD & Malaria Meningkat';
      adviceText = 'Secara nasional, data WHO menunjukkan kenaikan kasus Demam Berdarah dan Malaria. Disarankan untuk segera melakukan pembelian (Purchase Order) obat antipiretik (Paracetamol), cairan rehidrasi elektrolit, dan antimalaria (Kloroquin/Artemether) sebesar 30% di atas batas minStock.';
      cardColor = AppTheme.danger;
      cardIcon = Icons.warning_rounded;
    } else if (isDengueRising) {
      adviceTitle = 'REKOMENDASI RESTOCK: Tren Kasus DBD Meningkat';
      adviceText = 'Data epidemiologi menunjukkan peningkatan kasus Demam Berdarah di Indonesia. Disarankan untuk menambah persediaan Paracetamol (Tablet & Sirup Anak) serta multivitamin penambah imun sebesar 20% untuk mengantisipasi lonjakan resep pasien.';
      cardColor = Colors.orange;
      cardIcon = Icons.info_rounded;
    } else if (isMalariaRising) {
      adviceTitle = 'REKOMENDASI RESTOCK: Tren Kasus Malaria Meningkat';
      adviceText = 'Kasus Malaria terpantau meningkat secara nasional. Pastikan ketersediaan obat-obatan antimalaria dan pengusir nyamuk di outlet Anda memadai.';
      cardColor = AppTheme.primary;
      cardIcon = Icons.health_and_safety_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cardIcon, color: cardColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adviceTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cardColor == Colors.orange ? Colors.orange.shade900 : cardColor),
                ),
                const SizedBox(height: 8),
                Text(
                  adviceText,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseTrendLineChart(List<dynamic> trends) {
    // Kelompokkan data per kategori penyakit untuk fl_chart
    final malaria = trends.where((t) => t['diseaseCategory'] == 'MALARIA').toList()
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
    
    final dengue = trends.where((t) => t['diseaseCategory'] == 'DENGUE').toList()
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

    final tb = trends.where((t) => t['diseaseCategory'] == 'TB').toList()
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

    // Ambil tahun-tahun yang unik untuk label sumbu X
    final years = trends.map((t) => t['year'] as int).toSet().toList()..sort();
    
    // Konversi nilai ke ribuan untuk keterbacaan grafik (misal: 140.000 -> 140)
    List<FlSpot> malariaSpots = [];
    for (var m in malaria) {
      malariaSpots.add(FlSpot(m['year'].toDouble(), m['value'] / 1000.0));
    }

    List<FlSpot> dengueSpots = [];
    for (var d in dengue) {
      dengueSpots.add(FlSpot(d['year'].toDouble(), d['value'] / 1000.0));
    }

    List<FlSpot> tbSpots = [];
    for (var t in tb) {
      tbSpots.add(FlSpot(t['year'].toDouble(), t['value'] / 1000.0));
    }

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Malaria (Est. Kasus / 1K)', AppTheme.primary),
            const SizedBox(width: 16),
            _buildLegendItem('DBD (Laporan Kasus / 1K)', Colors.orange),
            const SizedBox(width: 16),
            _buildLegendItem('TBC (Incidence / 1K)', AppTheme.success),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 8),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, _) => Text('${val.toInt()}K', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (val, _) {
                        if (years.contains(val.toInt())) {
                          return Text('${val.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (malariaSpots.isNotEmpty)
                    LineChartBarData(
                      spots: malariaSpots,
                      isCurved: true,
                      color: AppTheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  if (dengueSpots.isNotEmpty)
                    LineChartBarData(
                      spots: dengueSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  if (tbSpots.isNotEmpty)
                    LineChartBarData(
                      spots: tbSpots,
                      isCurved: true,
                      color: AppTheme.success,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopSellingBarChart(List<dynamic> items) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (items.map((i) => i['totalSold'] as int).reduce((a, b) => a > b ? a : b).toDouble() * 1.2),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.grey.shade800,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final drugName = items[group.x]['name'];
              return BarTooltipItem(
                '$drugName\nTerjual: ${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < items.length) {
                  final String name = items[index]['name'];
                  // Truncate name if too long
                  final displayName = name.length > 8 ? '${name.substring(0, 7)}..' : name;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        displayName.toUpperCase(),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: (item['totalSold'] as int).toDouble(),
                color: AppTheme.primary,
                width: 14,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildFdaRecallPieChart(List<dynamic> recalls) {
    int class1 = 0;
    int class2 = 0;
    int class3 = 0;

    for (var r in recalls) {
      final classification = r['classification'] as String? ?? 'Class II';
      if (classification.contains('Class I')) {
        class1++;
      } else if (classification.contains('Class III')) {
        class3++;
      } else {
        class2++;
      }
    }

    final total = class1 + class2 + class3;
    if (total == 0) {
      return const Center(child: Text('Tidak ada data klasifikasi'));
    }

    final class1Percent = (class1 / total * 100).toStringAsFixed(0);
    final class2Percent = (class2 / total * 100).toStringAsFixed(0);
    final class3Percent = (class3 / total * 100).toStringAsFixed(0);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: [
                if (class1 > 0)
                  PieChartSectionData(
                    value: class1.toDouble(),
                    title: '$class1Percent%',
                    color: AppTheme.danger,
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                if (class2 > 0)
                  PieChartSectionData(
                    value: class2.toDouble(),
                    title: '$class2Percent%',
                    color: Colors.orange,
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                if (class3 > 0)
                  PieChartSectionData(
                    value: class3.toDouble(),
                    title: '$class3Percent%',
                    color: AppTheme.success,
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem('Class I (Bahaya Tinggi: $class1)', AppTheme.danger),
              const SizedBox(height: 12),
              _buildLegendItem('Class II (Bahaya Sedang: $class2)', Colors.orange),
              const SizedBox(height: 12),
              _buildLegendItem('Class III (Bahaya Rendah: $class3)', AppTheme.success),
            ],
          ),
        ),
      ],
    );
  }
}
