import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final salesAsync = ref.watch(salesReportProvider(selectedPeriod));
    final expiryAsync = ref.watch(expiryReportProvider);
    final inventoryAsync = ref.watch(inventoryReportProvider);
    final fdaRecallsAsync = ref.watch(fdaRecallsProvider);
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return MainLayout(
      currentRoute: '/reports',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Analisis penjualan dan stok apotek',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Filter periode
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      items: const [
                        DropdownMenuItem(
                            value: 'daily', child: Text('Hari Ini')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Minggu Ini')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Bulan Ini')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Tahun Ini')),
                      ],
                      onChanged: (v) =>
                          ref.read(selectedPeriodProvider.notifier).state = v!,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary cards
            salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) => Column(
                children: [
                  // Cards ringkasan
                  Row(
                    children: [
                      _ReportCard(
                        title: 'Total Pendapatan',
                        value: currency.format(data['summary']['totalRevenue']),
                        icon: Icons.payments_outlined,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 16),
                      _ReportCard(
                        title: 'Total Transaksi',
                        value: '${data['summary']['totalTransactions']}',
                        icon: Icons.receipt_long_outlined,
                        color: AppTheme.primaryLight,
                      ),
                      const SizedBox(width: 16),
                      _ReportCard(
                        title: 'Rata-rata Transaksi',
                        value: currency
                            .format(data['summary']['averageTransaction']),
                        icon: Icons.trending_up_outlined,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 16),
                      _ReportCard(
                        title: 'Total Item Terjual',
                        value: '${data['summary']['totalItems']}',
                        icon: Icons.inventory_outlined,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grafik penjualan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line chart penjualan harian
                      Expanded(
                        flex: 6,
                        child: _SalesChart(
                          dailyChart: List<Map<String, dynamic>>.from(
                              data['dailyChart']),
                          currency: currency,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Pie chart metode pembayaran
                      Expanded(
                        flex: 4,
                        child: _PaymentChart(
                          paymentBreakdown: Map<String, dynamic>.from(
                              data['paymentBreakdown']),
                          currency: currency,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Top 10 obat terlaris
                  _TopDrugsTable(
                    topDrugs: List<Map<String, dynamic>>.from(data['topDrugs']),
                    currency: currency,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Laporan expired
            expiryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (data) => _ExpiryReport(data: data),
            ),
            const SizedBox(height: 24),

            // Laporan Inventaris (Persebaran Kategori)
            inventoryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (data) => _InventoryDistributionChart(data: data),
            ),
            const SizedBox(height: 24),

            // Laporan Recall FDA (Keamanan Obat Global)
            fdaRecallsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (recalls) => _FdaRecallsWidget(recalls: recalls),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget report card
class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Grafik penjualan harian
class _SalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyChart;
  final NumberFormat currency;

  const _SalesChart({
    required this.dailyChart,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyChart.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Belum ada data penjualan')),
      );
    }

    final spots = dailyChart.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        (e.value['revenue'] as num).toDouble(),
      );
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tren Penjualan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) => Text(
                        currency.format(value),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < dailyChart.length) {
                          final date = dailyChart[i]['date'] as String;
                          return Text(
                            date.substring(5),
                            style: const TextStyle(fontSize: 9),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: (dailyChart.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.1),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pie chart metode pembayaran
class _PaymentChart extends StatelessWidget {
  final Map<String, dynamic> paymentBreakdown;
  final NumberFormat currency;

  const _PaymentChart({
    required this.paymentBreakdown,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (paymentBreakdown.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Belum ada data')),
      );
    }

    final colors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.accent,
      Colors.purple,
    ];

    final entries = paymentBreakdown.entries.toList();
    final total =
        entries.fold<double>(0, (sum, e) => sum + (e.value as num).toDouble());

    final sections = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final value = (e.value as num).toDouble();
      final percent = total > 0 ? (value / total * 100) : 0;

      return PieChartSectionData(
        value: value,
        title: '${percent.toStringAsFixed(0)}%',
        color: colors[i % colors.length],
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metode Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(sections: sections)),
          ),
          const SizedBox(height: 16),

          // Legend
          ...entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(e.key, style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(
                    currency.format(e.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Tabel top obat terlaris
class _TopDrugsTable extends StatelessWidget {
  final List<Map<String, dynamic>> topDrugs;
  final NumberFormat currency;

  const _TopDrugsTable({
    required this.topDrugs,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 10 Obat Terlaris',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (topDrugs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data penjualan'),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FixedColumnWidth(40),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                // Header
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: ['#', 'Nama Obat', 'Terjual', 'Revenue']
                      .map((h) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ))
                      .toList(),
                ),

                // Data rows
                ...topDrugs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final drug = entry.value;
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: i < 3
                                ? AppTheme.warning
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(drug['name'] ?? '-'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${drug['quantity']} pcs'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          currency.format(drug['revenue']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
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

// Laporan expired
class _ExpiryReport extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ExpiryReport({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Kadaluarsa Obat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Summary badges
          Row(
            children: [
              _ExpiryBadge(
                label: 'Sudah Expired',
                count: summary['expiredCount'],
                color: AppTheme.danger,
              ),
              const SizedBox(width: 12),
              _ExpiryBadge(
                label: 'Kritis (< 30 hari)',
                count: summary['criticalCount'],
                color: AppTheme.warning,
              ),
              const SizedBox(width: 12),
              _ExpiryBadge(
                label: 'Perhatian (< 90 hari)',
                count: summary['warningCount'],
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ExpiryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget Persebaran Kategori Obat (Pie Chart)
class _InventoryDistributionChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const _InventoryDistributionChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final drugs = List<Map<String, dynamic>>.from(data['drugs'] ?? []);
    if (drugs.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Belum ada data inventaris')),
      );
    }

    final categoryCounts = <String, int>{};
    for (final d in drugs) {
      final cat = d['category'] as String? ?? 'BEBAS';
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final colors = {
      'BEBAS': Colors.green,
      'BEBAS_TERBATAS': Colors.blue,
      'KERAS': Colors.red,
      'NARKOTIKA': Colors.purple,
      'PSIKOTROPIKA': Colors.orange,
    };

    final total = categoryCounts.values.fold<int>(0, (sum, count) => sum + count);

    final sections = categoryCounts.entries.map((e) {
      final color = colors[e.key] ?? Colors.grey;
      final value = e.value.toDouble();
      final percent = total > 0 ? (value / total * 100) : 0.0;

      return PieChartSectionData(
        value: value,
        title: '${percent.toStringAsFixed(1)}%',
        color: color,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Persebaran Kategori Obat (Inventaris)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: categoryCounts.entries.map((e) {
                    final color = colors[e.key] ?? Colors.grey;
                    final displayKey = e.key.replaceAll('_', ' ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayKey,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value} obat',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget Feed Recall FDA (Keamanan Obat Global)
class _FdaRecallsWidget extends StatelessWidget {
  final List<dynamic> recalls;

  const _FdaRecallsWidget({required this.recalls});

  @override
  Widget build(BuildContext context) {
    if (recalls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.gpp_good, color: AppTheme.success, size: 48),
              SizedBox(height: 12),
              Text(
                'Tidak ada laporan recall obat FDA terbaru',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Data dari openFDA API menunjukkan obat aman.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
              SizedBox(width: 8),
              Text(
                'Keamanan Obat Global & Recall (openFDA API)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Informasi penarikan obat terbaru yang dirilis oleh FDA Amerika Serikat sebagai referensi keselamatan farmasi global.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recalls.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final recall = recalls[index];
              final classification = recall['classification'] as String? ?? 'Class II';
              final status = recall['status'] as String? ?? 'Ongoing';
              final dateStr = recall['report_date'] as String? ?? '';
              
              Color classColor = Colors.orange;
              if (classification.contains('Class I')) {
                classColor = Colors.red;
              } else if (classification.contains('Class III')) {
                classColor = Colors.green;
              }

              String formattedDate = dateStr;
              if (dateStr.length == 8) {
                formattedDate = '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: classColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: classColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            classification,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: classColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recall['product_description'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alasan Recall: ${recall['reason_for_recall'] as String? ?? ""}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
