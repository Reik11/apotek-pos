import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../providers/purchase_orders_provider.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  Map<String, dynamic>? _selectedPo;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _statusColors = {
    'PENDING': Color(0xFF64748B), // Slate
    'ORDERED': Color(0xFF2563EB), // Blue
    'RECEIVED': AppTheme.success,  // Green
    'CANCELLED': AppTheme.danger,  // Red
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poState = ref.watch(purchaseOrdersProvider);
    final suppliersState = ref.watch(suppliersProvider);
    final inventoryState = ref.watch(inventoryProvider);

    final filtered = poState.purchaseOrders.where((po) {
      final q = _searchQuery.toLowerCase();
      final supplierName = po['supplier'] != null ? (po['supplier']['name'] ?? '') : '';
      final poId = po['id'] ?? '';
      return supplierName.toLowerCase().contains(q) ||
          poId.toLowerCase().contains(q) ||
          (po['status'] ?? '').toLowerCase().contains(q);
    }).toList();

    // If selected PO is updated in the list, keep it synchronized in the state
    if (_selectedPo != null) {
      final index = poState.purchaseOrders.indexWhere((po) => po['id'] == _selectedPo!['id']);
      if (index != -1) {
        _selectedPo = poState.purchaseOrders[index];
      }
    }

    return MainLayout(
      currentRoute: '/purchase-orders',
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
                        'Purchase Order (PO)',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kelola pengadaan obat dan transaksi pembelian ke supplier',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: suppliersState.suppliers.isEmpty
                      ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Tambahkan supplier terlebih dahulu sebelum membuat PO!'),
                          backgroundColor: AppTheme.danger,
                        ))
                      : () => _showCreatePoDialog(context),
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('Buat PO Baru'),
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
                hintText: 'Cari supplier, ID PO, atau status...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Content Layout
          Expanded(
            child: poState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PO List Table
                      Expanded(
                        flex: 3,
                        child: filtered.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Tidak ada Purchase Order ditemukan', style: TextStyle(color: AppTheme.textSecondary)),
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
                                        0: FlexColumnWidth(1.2),
                                        1: FlexColumnWidth(2),
                                        2: FlexColumnWidth(1.5),
                                        3: FlexColumnWidth(1.5),
                                        4: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: const BoxDecoration(color: AppTheme.primary),
                                          children: ['Tanggal', 'Supplier', 'Total Transaksi', 'Status', 'Aksi']
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
                                          final po = entry.value;
                                          final status = po['status'] as String? ?? 'PENDING';
                                          final statusColor = _statusColors[status] ?? AppTheme.primary;
                                          final orderDate = po['orderDate'] != null
                                              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(po['orderDate']))
                                              : '-';
                                          final formattedTotal = NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0,
                                          ).format(po['totalAmount'] ?? 0);
                                          final supplierName = po['supplier'] != null ? (po['supplier']['name'] ?? '-') : '-';

                                          final isSelected = _selectedPo != null && _selectedPo!['id'] == po['id'];

                                          return TableRow(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primary.withValues(alpha: 0.08)
                                                  : i % 2 == 0
                                                      ? Colors.white
                                                      : const Color(0xFFF8FAFC),
                                            ),
                                            children: [
                                              // Tanggal
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Text(orderDate, style: const TextStyle(fontSize: 12)),
                                              ),
                                              // Supplier
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Text(supplierName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              ),
                                              // Total
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Text(formattedTotal, style: const TextStyle(fontSize: 12)),
                                              ),
                                              // Status
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              // Aksi / Detail
                                              Padding(
                                                padding: const EdgeInsets.all(4),
                                                child: TextButton(
                                                  onPressed: () => setState(() => _selectedPo = po),
                                                  child: const Text('Detail', style: TextStyle(fontSize: 12)),
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

                      // PO Detail Panel
                      Expanded(
                        flex: 2,
                        child: _selectedPo == null
                            ? Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Pilih salah satu Purchase Order\nuntuk melihat rincian detail',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ),
                              )
                            : _buildPoDetailPanel(context, _selectedPo!),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoDetailPanel(BuildContext context, Map<String, dynamic> po) {
    final status = po['status'] as String? ?? 'PENDING';
    final statusColor = _statusColors[status] ?? AppTheme.primary;
    final orderDate = po['orderDate'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(po['orderDate']))
        : '-';
    final supplierName = po['supplier'] != null ? (po['supplier']['name'] ?? '-') : '-';
    final supplierPhone = po['supplier'] != null ? (po['supplier']['phone'] ?? '-') : '-';
    final supplierAddress = po['supplier'] != null ? (po['supplier']['address'] ?? '-') : '-';
    final formattedTotal = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(po['totalAmount'] ?? 0);
    final items = po['items'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detail Purchase Order',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedPo = null),
                ),
              ],
            ),
          ),

          // Detail Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID PO & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ID PO: ${po['id'].substring(0, 8).toUpperCase()}...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Info PO
                  _buildInfoRow('Tanggal Order', orderDate),
                  _buildInfoRow('Nama Supplier', supplierName),
                  _buildInfoRow('No. Telepon', supplierPhone),
                  _buildInfoRow('Alamat Gudang', supplierAddress),

                  const SizedBox(height: 16),
                  const Text(
                    'Daftar Item Obat:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Items Table/List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      final formattedPrice = NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(item['price'] ?? 0);
                      final formattedSub = NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(item['subtotal'] ?? 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['drugName'] ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['quantity']} pcs x $formattedPrice',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formattedSub,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Total Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pengadaan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        formattedTotal,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions
          if (status == 'PENDING' || status == 'ORDERED')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                      onPressed: () => _updatePoStatus(po['id'], 'CANCELLED'),
                      child: const Text('Batalkan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Progress Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: status == 'PENDING'
                          ? () => _updatePoStatus(po['id'], 'ORDERED')
                          : () => _showReceiveItemsDialog(context, po),
                      child: Text(status == 'PENDING' ? 'Kirim Order' : 'Terima Barang'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _updatePoStatus(String id, String status) async {
    final success = await ref.read(purchaseOrdersProvider.notifier).updateStatus(id, status, null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Status PO berhasil diperbarui!' : 'Gagal memperbarui status PO'),
        backgroundColor: success ? AppTheme.success : AppTheme.danger,
      ));
    }
  }

  void _showReceiveItemsDialog(BuildContext context, Map<String, dynamic> po) {
    final items = po['items'] as List<dynamic>? ?? [];
    
    // Map to store inputs: key = drugId, value = { 'batchNumber': controller, 'expiredDate': DateTime }
    final controllers = <String, TextEditingController>{};
    final dates = <String, DateTime>{};

    for (var item in items) {
      final drugId = item['drugId'] as String;
      controllers[drugId] = TextEditingController();
      dates[drugId] = DateTime.now().add(const Duration(days: 365)); // default 1 year from now
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Penerimaan Barang & Input Batch'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan Nomor Batch dan Tanggal Kedaluwarsa untuk setiap item obat yang diterima:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...items.map((item) {
                    final drugId = item['drugId'] as String;
                    final name = item['drugName'] ?? '-';
                    final qty = item['quantity'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name ($qty pcs)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Batch Number
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Nomor Batch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: controllers[drugId],
                                      decoration: const InputDecoration(
                                        hintText: 'Misal: BATCH001',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Expired Date Picker
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tanggal Kadaluarsa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: dates[drugId]!,
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                                        );
                                        if (picked != null) {
                                          setS(() => dates[drugId] = picked);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(dates[drugId]!),
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primary),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                // Validate inputs
                for (var key in controllers.keys) {
                  if (controllers[key]!.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Semua kolom Nomor Batch harus diisi!'),
                      backgroundColor: AppTheme.danger,
                    ));
                    return;
                  }
                }

                // Prepare receive details payload
                final receiveDetails = items.map((item) {
                  final drugId = item['drugId'] as String;
                  return {
                    'drugId': drugId,
                    'batchNumber': controllers[drugId]!.text,
                    'expiredDate': dates[drugId]!.toIso8601String(),
                  };
                }).toList();

                final success = await ref
                    .read(purchaseOrdersProvider.notifier)
                    .updateStatus(po['id'], 'RECEIVED', receiveDetails);

                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                  // Refresh inventory list to update stock count
                  ref.read(inventoryProvider.notifier).loadDrugs();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Barang berhasil diterima! Stok inventaris otomatis ditambahkan.'),
                    backgroundColor: AppTheme.success,
                  ));
                }
              },
              child: const Text('Konfirmasi Terima'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePoDialog(BuildContext context) {
    final suppliersState = ref.read(suppliersProvider);
    final inventoryState = ref.read(inventoryProvider);

    String? selectedSupplierId = suppliersState.suppliers.first['id'];
    final selectedItems = <Map<String, dynamic>>[]; // { 'drugId': String, 'name': String, 'qty': int, 'price': double }
    
    // Add item form controllers
    String? selectedDrugId = inventoryState.drugs.isNotEmpty ? inventoryState.drugs.first.id : null;
    final qtyCtrl = TextEditingController(text: '10');
    final priceCtrl = TextEditingController(text: '0');

    // Auto fill price when drug is selected
    if (selectedDrugId != null) {
      final drug = inventoryState.drugs.firstWhere((d) => d.id == selectedDrugId);
      priceCtrl.text = drug.buyPrice.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          double totalAmount = selectedItems.fold(0, (sum, item) => sum + (item['qty'] * item['price']));

          return AlertDialog(
            title: const Text('Buat Purchase Order Baru'),
            content: SizedBox(
              width: 700,
              height: 500,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Config & Add Item form
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pilih Supplier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedSupplierId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: suppliersState.suppliers
                                .map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String)))
                                .toList(),
                            onChanged: (v) => setS(() => selectedSupplierId = v),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text('Tambah Item Obat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                          const SizedBox(height: 12),
                          const Text('Pilih Obat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedDrugId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: inventoryState.drugs
                                .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) {
                              setS(() {
                                selectedDrugId = v;
                                final drug = inventoryState.drugs.firstWhere((d) => d.id == v);
                                priceCtrl.text = drug.buyPrice.toStringAsFixed(0);
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Jumlah (pcs)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: qtyCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Harga Beli (Rp)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: priceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (selectedDrugId == null) return;
                                final qty = int.tryParse(qtyCtrl.text) ?? 0;
                                final price = double.tryParse(priceCtrl.text) ?? 0;
                                if (qty <= 0 || price <= 0) return;

                                final drug = inventoryState.drugs.firstWhere((d) => d.id == selectedDrugId);
                                
                                // Check if drug already added
                                final existingIdx = selectedItems.indexWhere((item) => item['drugId'] == selectedDrugId);
                                if (existingIdx != -1) {
                                  setS(() {
                                    selectedItems[existingIdx]['qty'] += qty;
                                    selectedItems[existingIdx]['price'] = price;
                                  });
                                } else {
                                  setS(() {
                                    selectedItems.add({
                                      'drugId': selectedDrugId,
                                      'name': drug.name,
                                      'qty': qty,
                                      'price': price,
                                    });
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Tambah Obat', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 24),
                  // Right side: Items ordered list & Total
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daftar Transaksi PO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: selectedItems.isEmpty
                              ? const Center(
                                  child: Text('Belum ada obat ditambahkan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                )
                              : ListView.builder(
                                  itemCount: selectedItems.length,
                                  itemBuilder: (context, idx) {
                                    final item = selectedItems[idx];
                                    final sub = item['qty'] * item['price'];
                                    final formattedSub = NumberFormat.currency(
                                      locale: 'id_ID',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(sub);

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                      subtitle: Text('${item['qty']} pcs x Rp ${item['price'].toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(formattedSub, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary)),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger, size: 16),
                                            onPressed: () => setS(() => selectedItems.removeAt(idx)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total PO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                            ),
                          ],
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
                onPressed: selectedItems.isEmpty || selectedSupplierId == null
                    ? null
                    : () async {
                        final itemsData = selectedItems.map((item) => {
                          'drugId': item['drugId'],
                          'quantity': item['qty'],
                          'price': item['price'],
                        }).toList();

                        final ok = await ref.read(purchaseOrdersProvider.notifier).createPurchaseOrder({
                          'supplierId': selectedSupplierId,
                          'items': itemsData,
                        });

                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Purchase Order berhasil dibuat! Status PENDING.'),
                            backgroundColor: AppTheme.success,
                          ));
                        }
                      },
                child: const Text('Simpan PO'),
              ),
            ],
          );
        },
      ),
    );
  }
}
