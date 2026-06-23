import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/suppliers_provider.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersState = ref.watch(suppliersProvider);
    final filtered = suppliersState.suppliers.where((s) {
      final q = _searchQuery.toLowerCase();
      return (s['name'] ?? '').toLowerCase().contains(q) ||
          (s['phone'] ?? '').toLowerCase().contains(q) ||
          (s['email'] ?? '').toLowerCase().contains(q) ||
          (s['address'] ?? '').toLowerCase().contains(q);
    }).toList();

    return MainLayout(
      currentRoute: '/suppliers',
      child: Column(
        children: [
          // Header
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
                        'Manajemen Supplier',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kelola data distributor dan supplier obat apotek',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditSupplierDialog(context),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Tambah Supplier'),
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari nama, telepon, email, atau alamat...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Content
          Expanded(
            child: suppliersState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Tidak ada supplier ditemukan', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.5),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(2.5),
                                3: FlexColumnWidth(4),
                                4: FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.primary),
                                  children: ['Nama Supplier', 'No. Telepon', 'Email', 'Alamat', 'Aksi']
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(h,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                ),
                                ...filtered.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final supplier = entry.value;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                    ),
                                    children: [
                                      // Nama
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          supplier['name'] ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                      // Telepon
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(supplier['phone'] ?? '-',
                                            style: const TextStyle(fontSize: 12)),
                                      ),
                                      // Email
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(supplier['email'] ?? '-',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Alamat
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(supplier['address'] ?? '-',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Aksi
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined,
                                                  color: AppTheme.primary, size: 18),
                                              tooltip: 'Edit Supplier',
                                              onPressed: () => _showAddEditSupplierDialog(context, supplier),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded,
                                                  color: AppTheme.danger, size: 18),
                                              tooltip: 'Hapus Supplier',
                                              onPressed: () => _confirmDelete(context, supplier),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Supplier'),
        content: Text('Apakah Anda yakin ingin menghapus supplier "${supplier['name']}"?\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(suppliersProvider.notifier).deleteSupplier(supplier['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Supplier berhasil dihapus' : 'Gagal menghapus supplier'),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ));
      }
    }
  }

  void _showAddEditSupplierDialog(BuildContext context, [Map<String, dynamic>? supplier]) {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?['name']);
    final phoneCtrl = TextEditingController(text: supplier?['phone']);
    final emailCtrl = TextEditingController(text: supplier?['email']);
    final addressCtrl = TextEditingController(text: supplier?['address']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier Baru'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Supplier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Masukkan nama supplier/distributor')),
                const SizedBox(height: 12),
                const Text('No. Telepon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '08xx-xxxx-xxxx')),
                const SizedBox(height: 12),
                const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'sales@distributor.com')),
                const SizedBox(height: 12),
                const Text('Alamat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: addressCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Alamat lengkap kantor/gudang')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final data = {
                'name': nameCtrl.text,
                'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                'address': addressCtrl.text.isEmpty ? null : addressCtrl.text,
              };

              final ok = isEdit
                  ? await ref.read(suppliersProvider.notifier).updateSupplier(supplier['id'], data)
                  : await ref.read(suppliersProvider.notifier).createSupplier(data);

              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit ? 'Supplier berhasil diperbarui!' : 'Supplier berhasil ditambahkan!'),
                  backgroundColor: AppTheme.success,
                ));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
