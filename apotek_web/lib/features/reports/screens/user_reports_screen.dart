import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/reports_provider.dart';
import '../../../core/api/api_client.dart';

class UserReportsScreen extends ConsumerStatefulWidget {
  const UserReportsScreen({super.key});

  @override
  ConsumerState<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends ConsumerState<UserReportsScreen> {
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';

  final List<String> _statuses = ['All', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  final List<String> _categories = [
    'All',
    'GENERAL',
    'ORDER',
    'DRUG_QUALITY',
    'SERVICE',
    'PAYMENT',
    'OTHER'
  ];

  String _buildQueryString() {
    final params = <String>[];
    if (_selectedStatus != 'All') {
      params.add('status=$_selectedStatus');
    }
    if (_selectedCategory != 'All') {
      params.add('category=$_selectedCategory');
    }
    return params.isEmpty ? '' : '?${params.join('&')}';
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'GENERAL':
        return 'Umum';
      case 'ORDER':
        return 'Pesanan';
      case 'DRUG_QUALITY':
        return 'Kualitas Obat';
      case 'SERVICE':
        return 'Layanan';
      case 'PAYMENT':
        return 'Pembayaran';
      case 'OTHER':
        return 'Lainnya';
      default:
        return category;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showReplyDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => _ReplyDialog(
        report: report,
        onSuccess: () {
          ref.refresh(adminReportsProvider(_buildQueryString()));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queryString = _buildQueryString();
    final reportsAsync = ref.watch(adminReportsProvider(queryString));

    return MainLayout(
      currentRoute: '/admin-reports',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Laporan Pengaduan Pengguna',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Kelola keluhan, pengaduan, dan saran dari pasien/pengguna.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Filter bar
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
                  // Filter Status
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        items: _statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status == 'All' ? 'Semua' : status,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Filter Kategori
                  const Text(
                    'Kategori:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        items: _categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat == 'All' ? 'Semua' : _getCategoryText(cat),
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Refresh Button
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.refresh(adminReportsProvider(queryString)),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content Table
            reportsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 48),
                      const SizedBox(height: 12),
                      Text('Gagal memuat data: $err'),
                    ],
                  ),
                ),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.mark_chat_read,
                              color: Colors.grey, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada laporan pengaduan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Laporan pengaduan pengguna dengan filter ini kosong.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.shadowSubtle,
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2), // Pengirim
                        1: FlexColumnWidth(2), // Kategori & Tanggal
                        2: FlexColumnWidth(3), // Laporan
                        3: FlexColumnWidth(1.5), // Status & Balasan
                        4: FixedColumnWidth(120), // Aksi
                      },
                      children: [
                        // Header Table
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                          ),
                          children: [
                            'Pengirim',
                            'Kategori / Waktu',
                            'Isi Laporan',
                            'Status / Reply',
                            'Aksi'
                          ].map((h) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Data rows
                        ...reports.map((report) {
                          final user = report['user'] ?? {};
                          final title = report['title'] ?? '';
                          final message = report['message'] ?? '';
                          final category = report['category'] ?? 'GENERAL';
                          final status = report['status'] ?? 'OPEN';
                          final date = DateTime.parse(report['createdAt']);
                          final formattedDate =
                              DateFormat('dd MMM yyyy, HH:mm').format(date);
                          final hasReply = report['adminReply'] != null;

                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            children: [
                              // Column 1: Pengirim
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['name'] ?? 'Pasien',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      user['email'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              // Column 2: Kategori & Tanggal
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getCategoryText(category),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              // Column 3: Isi Laporan
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Column 4: Status / Reply
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _getStatusColor(status)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          hasReply
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_actions_rounded,
                                          size: 14,
                                          color: hasReply
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasReply ? 'Dibalas' : 'Belum Dibalas',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: hasReply
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Column 5: Aksi
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: ElevatedButton(
                                  onPressed: () => _showReplyDialog(report),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasReply
                                        ? AppTheme.primaryLight
                                        : AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    hasReply ? 'Lihat/Edit' : 'Balas',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onSuccess;

  const _ReplyDialog({required this.report, required this.onSuccess});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _replyController = TextEditingController();
  String _selectedStatus = 'RESOLVED';
  bool _isSubmitting = false;

  final List<String> _statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

  @override
  void initState() {
    super.initState();
    _replyController.text = widget.report['adminReply'] ?? '';
    _selectedStatus = widget.report['status'] ?? 'RESOLVED';
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan balasan tidak boleh kosong'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final id = widget.report['id'];
      await ApiClient.createDio().patch('/user-reports/$id/reply', data: {
        'replyMessage': _replyController.text.trim(),
        'status': _selectedStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balasan berhasil dikirim'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim balasan: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.report['user'] ?? {};
    final title = widget.report['title'] ?? '';
    final message = widget.report['message'] ?? '';

    return AlertDialog(
      title: const Text(
        'Respons Laporan Pengaduan',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Pengirim
              Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pengirim: ${user['name'] ?? 'Pasien'} (${user['email'] ?? ''})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Judul & Pesan Laporan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Status Dropdown
              Row(
                children: [
                  const Text(
                    'Ubah Status Laporan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        items: _statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input Balasan
              const Text(
                'Balasan Admin:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _replyController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tulis tanggapan atau solusi untuk pengaduan ini...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Kirim Balasan'),
        ),
      ],
    );
  }
}
