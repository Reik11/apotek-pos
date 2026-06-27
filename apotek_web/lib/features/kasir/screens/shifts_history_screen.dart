import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/shifts_history_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ShiftsHistoryScreen extends ConsumerStatefulWidget {
  const ShiftsHistoryScreen({super.key});

  @override
  ConsumerState<ShiftsHistoryScreen> createState() => _ShiftsHistoryScreenState();
}

class _ShiftsHistoryScreenState extends ConsumerState<ShiftsHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'OPEN', 'CLOSED'
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(shiftsHistoryProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isSuperAdmin = user?.role == 'SUPER_ADMIN';

    // Filter shifts based on query and status filter
    final filteredShifts = historyState.shifts.where((s) {
      final name = (s['cashier']?['name'] as String? ?? '').toLowerCase();
      final outletName = (s['outlet']?['name'] as String? ?? '').toLowerCase();
      final status = s['status'] as String? ?? '';
      
      final queryMatch = name.contains(_searchQuery.toLowerCase()) || 
                         outletName.contains(_searchQuery.toLowerCase());
                         
      final statusMatch = _statusFilter == 'ALL' || status == _statusFilter;
      
      return queryMatch && statusMatch;
    }).toList();

    // Summary calculations
    final totalShifts = filteredShifts.length;
    final totalSales = filteredShifts.fold<double>(0.0, (sum, s) => sum + (s['totalSales'] as num? ?? 0.0).toDouble());
    final totalDiff = filteredShifts.fold<double>(0.0, (sum, s) => sum + (s['difference'] as num? ?? 0.0).toDouble());

    return MainLayout(
      currentRoute: '/shifts',
      child: Column(
        children: [
          // ===== HEADER =====
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat & Audit Shift Kasir',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Pantau pembukaan laci kasir, transaksi terproses, dan audit selisih saldo kas',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Segarkan data',
                  onPressed: () => ref.read(shiftsHistoryProvider.notifier).loadShiftsHistory(),
                ),
              ],
            ),
          ),

          // ===== CONTENT AREA =====
          Expanded(
            child: historyState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : historyState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                            const SizedBox(height: 12),
                            Text(historyState.error!, style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.read(shiftsHistoryProvider.notifier).loadShiftsHistory(),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== SUMMARY CARDS =====
                            Row(
                              children: [
                                _SummaryCard(
                                  title: 'Total Shift Diaudit',
                                  value: '$totalShifts shift',
                                  icon: Icons.assignment_ind_rounded,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 16),
                                _SummaryCard(
                                  title: 'Total Penjualan Kasir',
                                  value: currency.format(totalSales),
                                  icon: Icons.payments_rounded,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(width: 16),
                                _SummaryCard(
                                  title: 'Akumulasi Selisih',
                                  value: currency.format(totalDiff),
                                  icon: Icons.compare_arrows_rounded,
                                  color: totalDiff == 0
                                      ? AppTheme.textSecondary
                                      : totalDiff < 0
                                          ? AppTheme.danger
                                          : Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ===== FILTER BAR =====
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.shadowSubtle,
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  // Search Field
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Cari kasir atau cabang...',
                                        prefixIcon: Icon(Icons.search),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Status Filter Dropdown
                                  Expanded(
                                    flex: 1,
                                    child: DropdownButtonFormField<String>(
                                      value: _statusFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Status Shift',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'ALL', child: Text('Semua Status')),
                                        DropdownMenuItem(value: 'OPEN', child: Text('Sedang Aktif')),
                                        DropdownMenuItem(value: 'CLOSED', child: Text('Sudah Tutup')),
                                      ],
                                      onChanged: (val) => setState(() => _statusFilter = val!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ===== TABLE CARD =====
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.shadowSubtle,
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (filteredShifts.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(48),
                                      child: Center(
                                        child: Text(
                                          'Tidak ada riwayat shift yang cocok',
                                          style: TextStyle(color: Colors.grey, fontSize: 15),
                                        ),
                                      ),
                                    )
                                  else
                                    Table(
                                      columnWidths: {
                                        0: const FlexColumnWidth(1),   // ID
                                        1: const FlexColumnWidth(2),   // Kasir
                                        if (isSuperAdmin) 2: const FlexColumnWidth(1.5), // Cabang
                                        3: const FlexColumnWidth(1.8), // Mulai
                                        4: const FlexColumnWidth(1.8), // Selesai
                                        5: const FlexColumnWidth(1.2), // Status
                                        6: const FlexColumnWidth(1.5), // Saldo Awal
                                        7: const FlexColumnWidth(1.5), // Penjualan
                                        8: const FlexColumnWidth(1.5), // Saldo Akhir
                                        9: const FlexColumnWidth(1.5), // Selisih
                                      },
                                      children: [
                                        // Header Row
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          children: [
                                            _buildHeaderCell('ID'),
                                            _buildHeaderCell('Kasir'),
                                            if (isSuperAdmin) _buildHeaderCell('Cabang'),
                                            _buildHeaderCell('Waktu Mulai'),
                                            _buildHeaderCell('Waktu Selesai'),
                                            _buildHeaderCell('Status'),
                                            _buildHeaderCell('Saldo Awal'),
                                            _buildHeaderCell('Penjualan'),
                                            _buildHeaderCell('Saldo Akhir'),
                                            _buildHeaderCell('Selisih'),
                                          ],
                                        ),
                                        // Data Rows
                                        ...filteredShifts.map((s) {
                                          final id = (s['id'] as String? ?? '').substring(0, 8).toUpperCase();
                                          final cashierName = s['cashier']?['name'] ?? '-';
                                          final outletName = s['outlet']?['name'] ?? '-';
                                          
                                          final startTime = s['startTime'] != null
                                              ? DateFormat('dd/MM HH:mm').format(DateTime.parse(s['startTime']).toLocal())
                                              : '-';
                                          final endTime = s['endTime'] != null
                                              ? DateFormat('dd/MM HH:mm').format(DateTime.parse(s['endTime']).toLocal())
                                              : '-';
                                              
                                          final status = s['status'] as String? ?? 'OPEN';
                                          final startBal = (s['startBalance'] as num? ?? 0.0).toDouble();
                                          final sales = (s['totalSales'] as num? ?? 0.0).toDouble();
                                          final endBal = s['endBalance'] != null ? (s['endBalance'] as num).toDouble() : null;
                                          final difference = s['difference'] != null ? (s['difference'] as num).toDouble() : null;

                                          return TableRow(
                                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                                            children: [
                                              _buildCell(Text(id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary))),
                                              _buildCell(Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                                                    child: Text(
                                                      cashierName.isNotEmpty ? cashierName[0].toUpperCase() : 'K',
                                                      style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(cashierName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                                ],
                                              )),
                                              if (isSuperAdmin) _buildCell(Text(outletName, style: const TextStyle(fontSize: 12))),
                                              _buildCell(Text(startTime, style: const TextStyle(fontSize: 12))),
                                              _buildCell(Text(endTime, style: const TextStyle(fontSize: 12))),
                                              _buildCell(_buildStatusBadge(status)),
                                              _buildCell(Text(currency.format(startBal), style: const TextStyle(fontSize: 12))),
                                              _buildCell(Text(currency.format(sales), style: const TextStyle(fontSize: 12))),
                                              _buildCell(Text(endBal != null ? currency.format(endBal) : '-', style: const TextStyle(fontSize: 12))),
                                              _buildCell(_buildDifferenceText(status, difference)),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isOpen = status == 'OPEN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (isOpen ? AppTheme.success : AppTheme.textSecondary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOpen ? 'AKTIF' : 'TUTUP',
        style: TextStyle(
          fontSize: 10,
          color: isOpen ? AppTheme.success : AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDifferenceText(String status, double? difference) {
    if (status == 'OPEN' || difference == null) {
      return const Text('-', style: TextStyle(color: Colors.grey, fontSize: 12));
    }
    
    final Color textColor;
    final String prefix;
    if (difference == 0) {
      textColor = Colors.grey.shade600;
      prefix = '';
    } else if (difference < 0) {
      textColor = AppTheme.danger;
      prefix = '';
    } else {
      textColor = Colors.orange;
      prefix = '+';
    }

    return Text(
      '$prefix${currency.format(difference)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
