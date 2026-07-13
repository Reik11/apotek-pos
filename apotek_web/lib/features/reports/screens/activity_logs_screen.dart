import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/sync_provider.dart';

class ActivityLogsScreen extends ConsumerWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');

    return MainLayout(
      currentRoute: '/activity-logs',
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Header Section =====
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Aktivitas Pengguna',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Jejak audit keamanan sistem (Audit Trail) untuk memantau perubahan data.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(activityLogsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: Colors.grey, width: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ===== Main Content Card =====
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowSubtle,
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: logsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.danger,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text('Gagal memuat log audit: $err'),
                        ],
                      ),
                    ),
                  ),
                  data: (data) {
                    final List<dynamic> logs = data['logs'] ?? [];

                    if (logs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: AppTheme.success,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada log aktivitas tercatat.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Aktivitas yang memodifikasi data akan muncul di sini.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Responsive Table
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC),
                            ),
                            dataRowMaxHeight: 64,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'WAKTU',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'PENGGUNA',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ROLE',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'AKSI',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'IP ADDRESS',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'DETAIL',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: logs.map((log) {
                              final user = log['user'] ?? {};
                              final userName = user['name'] ?? 'Tidak Dikenal';
                              final userEmail = user['email'] ?? '';
                              final userRole = user['role'] ?? '-';
                              final action = log['action'] ?? '';
                              final ipAddress = log['ipAddress'] ?? '-';
                              final details = log['details'] ?? '';
                              final createdAt = log['createdAt'] != null
                                  ? DateTime.parse(log['createdAt'])
                                  : DateTime.now();

                              // Get color badge based on HTTP Action
                              Color actionBadgeColor = Colors.grey;
                              if (action.startsWith('CREATE') ||
                                  action == 'REGISTER') {
                                actionBadgeColor = AppTheme.success;
                              } else if (action.startsWith('UPDATE') ||
                                  action.startsWith('PATCH')) {
                                actionBadgeColor = AppTheme.warning;
                              } else if (action.startsWith('DELETE')) {
                                actionBadgeColor = AppTheme.danger;
                              } else if (action.contains('LOGIN')) {
                                actionBadgeColor = AppTheme.primary;
                              }

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      dateFormat.format(createdAt.toLocal()),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          userEmail,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        userRole,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: actionBadgeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: actionBadgeColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        action,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: actionBadgeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      ipAddress,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                        color: AppTheme.primary,
                                      ),
                                      onPressed: () {
                                        _showDetailsDialog(
                                          context,
                                          action,
                                          details,
                                          userName,
                                          createdAt,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(
    BuildContext context,
    String action,
    String details,
    String userName,
    DateTime createdAt,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Audit Log Detail: $action'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pengguna: $userName'),
              const SizedBox(height: 4),
              Text(
                'Waktu: ${DateFormat('dd MMMM yyyy, HH:mm:ss WIB').format(createdAt.toLocal())}',
              ),
              const Divider(height: 24),
              const Text(
                'Data Payload Request:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: details.isEmpty || details == '{}'
                    ? const Text(
                        'Tidak ada payload / data kosong.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          details,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
