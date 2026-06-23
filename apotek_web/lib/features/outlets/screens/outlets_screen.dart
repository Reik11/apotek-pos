import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/outlets_provider.dart';

class OutletsScreen extends ConsumerStatefulWidget {
  const OutletsScreen({super.key});

  @override
  ConsumerState<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends ConsumerState<OutletsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outletsState = ref.watch(outletsProvider);
    final filtered = outletsState.outlets.where((o) {
      final q = _searchQuery.toLowerCase();
      return (o['name'] ?? '').toLowerCase().contains(q) ||
          (o['address'] ?? '').toLowerCase().contains(q) ||
          (o['phone'] ?? '').toLowerCase().contains(q);
    }).toList();

    return MainLayout(
      currentRoute: '/outlets',
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
                        'Manajemen Cabang / Outlet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kelola data cabang apotek dan koordinat GPS untuk pencarian terdekat',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditOutletDialog(context),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Tambah Outlet'),
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
                hintText: 'Cari nama cabang, alamat, atau nomor telepon...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Content
          Expanded(
            child: outletsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Tidak ada outlet ditemukan', style: TextStyle(color: AppTheme.textSecondary)),
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
                                1: FlexColumnWidth(4.5),
                                2: FlexColumnWidth(2.0),
                                3: FlexColumnWidth(1.5),
                                4: FlexColumnWidth(1.5),
                                5: FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.primary),
                                  children: ['Nama Outlet', 'Alamat', 'No. Telepon', 'Latitude', 'Longitude', 'Aksi']
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
                                  final outlet = entry.value;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                    ),
                                    children: [
                                      // Nama
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          outlet['name'] ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                      // Alamat
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(outlet['address'] ?? '-',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Telepon
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(outlet['phone'] ?? '-',
                                            style: const TextStyle(fontSize: 12)),
                                      ),
                                      // Lat
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(outlet['latitude']?.toString() ?? '-',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Long
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(outlet['longitude']?.toString() ?? '-',
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
                                              tooltip: 'Edit Outlet',
                                              onPressed: () => _showAddEditOutletDialog(context, outlet),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded,
                                                  color: AppTheme.danger, size: 18),
                                              tooltip: 'Hapus Outlet',
                                              onPressed: () => _confirmDelete(context, outlet),
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

  void _confirmDelete(BuildContext context, Map<String, dynamic> outlet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Text('Apakah Anda yakin ingin menghapus outlet "${outlet['name']}"?\nTindakan ini tidak dapat dibatalkan.'),
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
      final success = await ref.read(outletsProvider.notifier).deleteOutlet(outlet['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Outlet berhasil dihapus' : 'Gagal menghapus outlet'),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ));
      }
    }
  }

  void _showAddEditOutletDialog(BuildContext context, [Map<String, dynamic>? outlet]) {
    final isEdit = outlet != null;
    final nameCtrl = TextEditingController(text: outlet?['name']);
    final addressCtrl = TextEditingController(text: outlet?['address']);
    final phoneCtrl = TextEditingController(text: outlet?['phone']);
    final latCtrl = TextEditingController(text: outlet?['latitude']?.toString());
    final lngCtrl = TextEditingController(text: outlet?['longitude']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Outlet' : 'Tambah Outlet Baru'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Outlet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Apotek POS Cabang ...')),
                const SizedBox(height: 12),
                const Text('Alamat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: addressCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Alamat lengkap outlet')),
                const SizedBox(height: 12),
                const Text('No. Telepon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '021-xxxxxxx')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latitude (opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(controller: latCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '-6.2000')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Longitude (opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(controller: lngCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '106.8166')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;
              final data = {
                'name': nameCtrl.text,
                'address': addressCtrl.text,
                'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                'latitude': double.tryParse(latCtrl.text),
                'longitude': double.tryParse(lngCtrl.text),
              };

              final success = isEdit
                  ? await ref.read(outletsProvider.notifier).updateOutlet(outlet['id'], data)
                  : await ref.read(outletsProvider.notifier).createOutlet(data);

              if (success && ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit ? 'Outlet berhasil diperbarui' : 'Outlet berhasil ditambahkan'),
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
