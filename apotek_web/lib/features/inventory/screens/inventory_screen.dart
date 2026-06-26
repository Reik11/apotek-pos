import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/inventory_provider.dart';
import '../../../shared/models/drug_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../outlets/providers/outlets_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).checkSyncStatus();
      _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          ref.read(inventoryProvider.notifier).checkSyncStatus();
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);

    return MainLayout(
      currentRoute: '/inventory',
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventaris Obat',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Kelola stok dan data obat apotek',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: inventoryState.isSyncing
                          ? null
                          : () async {
                              await ref.read(inventoryProvider.notifier).syncAllDrugs();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Penyelarasan data FDA/RxNorm dimulai di background!'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                            },
                      icon: inventoryState.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                            )
                          : const Icon(Icons.sync),
                      label: Text(inventoryState.isSyncing ? 'Sedang Sinkronisasi...' : 'Sinkronisasi Medis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDrugDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Obat'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama obat...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      ref.read(inventoryProvider.notifier).search(value),
                ),
                const SizedBox(height: 8),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Semua Obat'),
                    Tab(text: 'Hampir Expired'),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1 — Semua obat
                inventoryState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : inventoryState.filteredDrugs.isEmpty
                        ? const Center(child: Text('Tidak ada obat'))
                        : _buildDrugTable(inventoryState.filteredDrugs),

                // Tab 2 — Hampir expired
                const _ExpiringDrugsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tabel daftar obat
  Widget _buildDrugTable(List<DrugModel> drugs) {
    final authState = ref.watch(authProvider);
    final isSuperAdmin = authState.user?.role == 'SUPER_ADMIN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(inventoryProvider.notifier).loadDrugs(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),

          // Table
          Container(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.5),
                  6: FlexColumnWidth(1.5),
                },
                children: [
                  // Header tabel
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.primary),
                    children: [
                      'Nama Obat',
                      'Kandungan',
                      'Kategori',
                      'Jenis',
                      'Stok',
                      'Harga Jual',
                      'Aksi',
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  // Baris data obat
                  ...drugs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final drug = entry.value;
                    final isLowStock = drug.totalStock <= drug.minStock;

                    return TableRow(
                      decoration: BoxDecoration(
                        color:
                            i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                      ),
                      children: [
                        // Nama
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                drug.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (drug.genericName != null && drug.genericName!.isNotEmpty)
                                Text(
                                  drug.genericName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: drug.outletId == null
                                      ? Colors.green.shade50
                                      : Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: drug.outletId == null
                                        ? Colors.green.shade200
                                        : Colors.blueGrey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  drug.outletId == null ? 'Katalog Global' : 'Kustom Cabang',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: drug.outletId == null
                                        ? Colors.green.shade800
                                        : Colors.blueGrey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Kandungan
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            drug.activeIngredient ?? '-',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),

                        // Kategori
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _CategoryBadge(category: drug.category),
                        ),

                        // Jenis
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: drug.type == 'GENERIK'
                                  ? AppTheme.success.withOpacity(0.1)
                                  : AppTheme.primaryLight.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              drug.type,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: drug.type == 'GENERIK'
                                    ? AppTheme.success
                                    : AppTheme.primaryLight,
                              ),
                            ),
                          ),
                        ),

                        // Stok
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              if (isLowStock)
                                const Icon(Icons.warning_amber,
                                    color: AppTheme.warning, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${drug.totalStock} ${drug.unit}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isLowStock
                                      ? AppTheme.danger
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Harga
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            currency.format(drug.sellPrice),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),                         // Aksi
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: AppTheme.success, size: 20),
                                tooltip: 'Tambah Stok',
                                onPressed: () =>
                                    _showAddBatchDialog(context, drug),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: AppTheme.primaryLight, size: 20),
                                tooltip: 'Info Obat',
                                onPressed: () =>
                                    _showDrugInfoDialog(context, drug),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: (drug.outletId == null && !isSuperAdmin)
                                      ? Colors.grey.shade400
                                      : AppTheme.danger,
                                  size: 20,
                                ),
                                tooltip: (drug.outletId == null && !isSuperAdmin)
                                    ? 'Katalog global tidak dapat dihapus oleh cabang'
                                    : 'Hapus Obat',
                                onPressed: (drug.outletId == null && !isSuperAdmin)
                                    ? null
                                    : () => _confirmDeleteDrug(context, drug),
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
        ],
      ),
    );
  }

  // Konfirmasi hapus obat
  void _confirmDeleteDrug(BuildContext context, DrugModel drug) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Obat'),
        content: Text(
          'Hapus "${drug.name}" dari inventaris?\nSemua data batch/stok akan ikut terhapus.',
        ),
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
      final ok = await ref.read(inventoryProvider.notifier).deleteDrug(drug.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '"${drug.name}" berhasil dihapus' : 'Gagal menghapus obat'),
          backgroundColor: ok ? AppTheme.success : AppTheme.danger,
        ));
      }
    }
  }

  // Dialog tambah obat baru
  void _showAddDrugDialog(BuildContext context) {
    final nameController = TextEditingController();
    final genericController = TextEditingController();
    final ingredientController = TextEditingController();
    final sellPriceController = TextEditingController();
    final buyPriceController = TextEditingController();
    final minStockController = TextEditingController(text: '10');
    String selectedCategory = 'BEBAS';
    String selectedType = 'GENERIK';
    bool isSearchingApi = false;
    List<DrugModel> localSuggestions = [];

    final outletsState = ref.read(outletsProvider);
    final authState = ref.read(authProvider);
    final isSuperAdmin = authState.user?.role == 'SUPER_ADMIN';
    String? selectedOutletId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Obat Baru'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama obat + cari API
                  const Text('Nama Obat',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Amoxicillin 500mg',
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val.trim().isEmpty) {
                                localSuggestions = [];
                              } else {
                                final lowerVal = val.toLowerCase();
                                localSuggestions = ref
                                    .read(inventoryProvider)
                                    .drugs
                                    .where((d) =>
                                        d.name.toLowerCase().contains(lowerVal) ||
                                        (d.genericName?.toLowerCase().contains(lowerVal) ?? false))
                                    .toList();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isSearchingApi
                            ? null
                            : () async {
                                setDialogState(() => isSearchingApi = true);
                                final info = await ref
                                    .read(inventoryProvider.notifier)
                                    .searchDrugInfo(nameController.text);
                                if (info != null) {
                                  final detail = info['rxnorm']?['detail'];
                                  if (detail != null) {
                                    genericController.text =
                                        detail['name'] ?? '';
                                    ingredientController.text =
                                        detail['ingredients'] ?? '';
                                  }
                                }
                                setDialogState(() => isSearchingApi = false);
                              },
                        icon: isSearchingApi
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search, size: 16),
                        label: const Text('Cari API'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                        ),
                      ),
                    ],
                  ),

                  // Suggestions list
                  if (localSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: localSuggestions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final drug = localSuggestions[index];
                          return ListTile(
                            dense: true,
                            hoverColor: AppTheme.primary.withOpacity(0.05),
                            title: Text(
                              drug.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              drug.genericName ?? drug.activeIngredient ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                drug.type,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () {
                              setDialogState(() {
                                nameController.text = drug.name;
                                genericController.text = drug.genericName ?? '';
                                ingredientController.text = drug.activeIngredient ?? '';
                                if (['BEBAS', 'BEBAS_TERBATAS', 'KERAS', 'NARKOTIKA', 'PSIKOTROPIKA'].contains(drug.category)) {
                                  selectedCategory = drug.category;
                                }
                                if (['GENERIK', 'PATEN', 'BPJS'].contains(drug.type)) {
                                  selectedType = drug.type;
                                }
                                buyPriceController.text = drug.buyPrice.toInt().toString();
                                sellPriceController.text = drug.sellPrice.toInt().toString();
                                localSuggestions.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Nama generik
                  const Text('Nama Generik',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: genericController,
                    decoration: const InputDecoration(
                        hintText: 'Otomatis terisi dari API'),
                  ),
                  const SizedBox(height: 16),

                  // Kandungan
                  const Text('Zat Aktif / Kandungan',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ingredientController,
                    decoration: const InputDecoration(
                        hintText: 'Otomatis terisi dari API'),
                  ),
                  const SizedBox(height: 16),

                  // Kategori & Jenis
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kategori',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: const InputDecoration(),
                              items: [
                                'BEBAS',
                                'BEBAS_TERBATAS',
                                'KERAS',
                                'NARKOTIKA',
                                'PSIKOTROPIKA',
                              ]
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedCategory = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jenis',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: const InputDecoration(),
                              items: ['GENERIK', 'PATEN', 'BPJS']
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedType = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Harga & Stok minimum
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Harga Beli',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: buyPriceController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(prefixText: 'Rp '),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Harga Jual',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: sellPriceController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(prefixText: 'Rp '),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: 16),
                    const Text('Outlet Penempatan',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedOutletId,
                      decoration: const InputDecoration(
                        hintText: 'Pilih Cabang (Global by default)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Global (Semua Cabang)'),
                        ),
                        ...outletsState.outlets.map((outlet) => DropdownMenuItem<String?>(
                              value: outlet['id'] as String?,
                              child: Text(outlet['name'] ?? ''),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => selectedOutletId = v),
                    ),
                  ],
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
              onPressed: () async {
                final success =
                    await ref.read(inventoryProvider.notifier).addDrug({
                  'name': nameController.text,
                  'genericName': genericController.text,
                  'activeIngredient': ingredientController.text,
                  'category': selectedCategory,
                  'type': selectedType,
                  'sellPrice': double.tryParse(sellPriceController.text) ?? 0,
                  'buyPrice': double.tryParse(buyPriceController.text) ?? 0,
                  'minStock': int.tryParse(minStockController.text) ?? 10,
                  'unit': 'tablet',
                  if (isSuperAdmin) 'outletId': selectedOutletId,
                });
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Obat berhasil ditambahkan!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog tambah stok batch
  void _showAddBatchDialog(BuildContext context, DrugModel drug) {
    final batchController = TextEditingController();
    final stockController = TextEditingController();
    final buyPriceController =
        TextEditingController(text: drug.buyPrice.toInt().toString());
    DateTime selectedDate = DateTime.now().add(const Duration(days: 365));

    final outletsState = ref.read(outletsProvider);
    final authState = ref.read(authProvider);
    final isSuperAdmin = authState.user?.role == 'SUPER_ADMIN';
    String? selectedOutletId = drug.outletId ?? (outletsState.outlets.isNotEmpty ? outletsState.outlets.first['id'] as String? : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Tambah Stok — ${drug.name}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nomor Batch',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: batchController,
                  decoration: const InputDecoration(hintText: 'BATCH001'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Jumlah Stok',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(suffixText: drug.unit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Harga Beli',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: buyPriceController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(prefixText: 'Rp '),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Tanggal Expired',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                      ],
                    ),
                  ),
                ),
                if (isSuperAdmin && drug.outletId == null) ...[
                  const SizedBox(height: 16),
                  const Text('Outlet Tujuan',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: selectedOutletId,
                    decoration: const InputDecoration(
                      hintText: 'Pilih Outlet',
                    ),
                    items: outletsState.outlets.map((outlet) => DropdownMenuItem<String?>(
                          value: outlet['id'] as String?,
                          child: Text(outlet['name'] ?? ''),
                        )).toList(),
                    onChanged: (v) => setDialogState(() => selectedOutletId = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success =
                    await ref.read(inventoryProvider.notifier).addBatch({
                  'drugId': drug.id,
                  'batchNumber': batchController.text,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'buyPrice': double.tryParse(buyPriceController.text) ?? 0,
                  'expiredDate': selectedDate.toIso8601String().split('T')[0],
                  if (isSuperAdmin) 'outletId': selectedOutletId,
                });
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stok berhasil ditambahkan!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog info obat dari API
  void _showDrugInfoDialog(BuildContext context, DrugModel drug) async {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final info = await ref
        .read(inventoryProvider.notifier)
        .searchDrugInfo(drug.genericName ?? drug.name);

    if (!context.mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(drug.name),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info?['fda'] != null) ...[
                  _InfoSection(
                    title: 'Indikasi',
                    content: info!['fda']['indications'] ?? '-',
                  ),
                  _InfoSection(
                    title: 'Efek Samping',
                    content: info['fda']['sideEffects'] ?? '-',
                  ),
                  _InfoSection(
                    title: 'Dosis',
                    content: info['fda']['dosage'] ?? '-',
                  ),
                  _InfoSection(
                    title: 'Peringatan',
                    content: info['fda']['warnings'] ?? '-',
                  ),
                ] else
                  const Text('Info FDA tidak tersedia untuk obat ini'),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

// Widget section info
class _InfoSection extends StatelessWidget {
  final String title;
  final String content;

  const _InfoSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 13, height: 1.5),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const Divider(height: 24),
      ],
    );
  }
}

// Widget badge kategori
class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (category) {
      case 'KERAS':
        color = AppTheme.danger;
        label = 'Keras';
        break;
      case 'BEBAS_TERBATAS':
        color = AppTheme.warning;
        label = 'Bebas Terbatas';
        break;
      case 'NARKOTIKA':
        color = const Color(0xFF7C3AED); // violet
        label = 'Narkotika';
        break;
      case 'PSIKOTROPIKA':
        color = const Color(0xFF7C3AED);
        label = 'Psikotropika';
        break;
      default: // BEBAS
        color = AppTheme.success;
        label = 'Bebas';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: color, width: 3), // ← left-border saja
        ),
      ),
      child: Text(
        label, // ← label lebih rapi (bukan ALL_CAPS)
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Tab obat hampir expired
class _ExpiringDrugsTab extends ConsumerWidget {
  const _ExpiringDrugsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<dynamic>(
      future: ApiClient.createDio().get('/drugs/expiring?days=90'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Gagal memuat data'));
        }

        final response = snapshot.data;
        final batches = (response?.data as List?) ?? [];

        if (batches.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppTheme.success, size: 48),
                SizedBox(height: 8),
                Text('Tidak ada obat yang akan kadaluarsa dalam 90 hari'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final batch = batches[index];
            final expiredDate = DateTime.parse(batch['expiredDate']);
            final daysLeft = expiredDate.difference(DateTime.now()).inDays;

            Color alertColor;
            if (daysLeft <= 7) {
              alertColor = AppTheme.danger;
            } else if (daysLeft <= 30) {
              alertColor = AppTheme.warning;
            } else {
              alertColor = Colors.orange;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alertColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.event_busy, color: alertColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch['drug']['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Batch: ${batch['batchNumber']} • Stok: ${batch['stock']}',
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
                        '$daysLeft hari lagi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: alertColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(expiredDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
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
