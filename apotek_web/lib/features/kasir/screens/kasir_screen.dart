import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/kasir_provider.dart';
import '../providers/shifts_provider.dart';
import '../../../shared/models/drug_model.dart';
import '../../../shared/widgets/drug_category_badge.dart';

class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  final _searchController = TextEditingController();
  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kasirState = ref.watch(kasirProvider);
    final shiftsState = ref.watch(shiftsProvider);

    if (shiftsState.isLoading) {
      return const MainLayout(
        currentRoute: '/kasir',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (shiftsState.activeShift == null) {
      return MainLayout(
        currentRoute: '/kasir',
        child: _buildOpenShiftView(context, ref),
      );
    }

    return MainLayout(
      currentRoute: '/kasir',
      child: Row(
        children: [
          // ===== KIRI: Cari & Pilih Obat =====
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Header & Search
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Kasir',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_open_rounded, size: 14, color: AppTheme.success),
                                const SizedBox(width: 4),
                                Text(
                                  'Kasir Aktif: ${currency.format(shiftsState.activeShift?['startBalance'] ?? 0)}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _showCloseShiftDialog(context, ref, shiftsState.activeShift!),
                            icon: const Icon(Icons.lock_outline_rounded, color: AppTheme.danger, size: 18),
                            label: const Text('Tutup Shift Kasir', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Cari obat by nama atau kandungan...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          ref.read(kasirProvider.notifier).searchDrugs(value);
                        },
                      ),
                    ],
                  ),
                ),

                // Hasil pencarian
                Expanded(
                  child: kasirState.isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : kasirState.searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search,
                                      size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Cari obat di atas\nuntuk mulai transaksi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: kasirState.searchResults.length,
                              itemBuilder: (context, index) {
                                final drug = kasirState.searchResults[index];
                                return _DrugCard(
                                  drug: drug,
                                  currency: currency,
                                  onTap: () => ref
                                      .read(kasirProvider.notifier)
                                      .addToCart(drug),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // ===== KANAN: Keranjang =====
          Container(
            width: 340,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              children: [
                // Header keranjang
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          color: AppTheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Keranjang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (kasirState.cartItems.isNotEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              ref.read(kasirProvider.notifier).clearCart(),
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: AppTheme.danger),
                          label: const Text('Kosongkan',
                              style: TextStyle(color: AppTheme.danger)),
                        ),
                    ],
                  ),
                ),

                // List item keranjang
                Expanded(
                  child: kasirState.cartItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'Keranjang kosong',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: kasirState.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = kasirState.cartItems[index];
                            return _CartItemWidget(
                              item: item,
                              currency: currency,
                              onRemove: () => ref
                                  .read(kasirProvider.notifier)
                                  .removeFromCart(item.drug.id),
                              onQuantityChanged: (qty) => ref
                                  .read(kasirProvider.notifier)
                                  .updateQuantity(item.drug.id, qty),
                            );
                          },
                        ),
                ),

                // Total & Bayar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text(currency.format(kasirState.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Diskon Row
                      Row(
                        children: [
                          const Text('Diskon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(width: 12),
                          // Toggle Rp / %
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ref.read(kasirProvider.notifier).updateDiscount('NOMINAL', 0.0);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kasirState.discountType == 'NOMINAL' ? AppTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Rp', style: TextStyle(fontSize: 10, color: kasirState.discountType == 'NOMINAL' ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    ref.read(kasirProvider.notifier).updateDiscount('PERCENT', 0.0);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kasirState.discountType == 'PERCENT' ? AppTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('%', style: TextStyle(fontSize: 10, color: kasirState.discountType == 'PERCENT' ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Input Value
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  hintText: kasirState.discountType == 'PERCENT' ? 'Ex: 10' : 'Ex: 5000',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  final doubleValue = double.tryParse(val) ?? 0.0;
                                  ref.read(kasirProvider.notifier).updateDiscount(kasirState.discountType, doubleValue);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (kasirState.discountAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Potongan', style: TextStyle(fontSize: 12, color: AppTheme.danger)),
                            Text('- ${currency.format(kasirState.discountAmount)}', style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            currency.format(kasirState.totalAmount),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Error message
                      if (kasirState.error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            kasirState.error!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 13),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: kasirState.cartItems.isEmpty ||
                                  kasirState.isProcessing
                              ? null
                              : () => _showPaymentDialog(
                                  context, ref, kasirState.totalAmount),
                          icon: kasirState.isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.payment),
                          label: const Text('Proses Pembayaran',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dialog pembayaran
  void _showPaymentDialog(BuildContext context, WidgetRef ref, double total) {
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String selectedMethod = 'CASH';
    final amountController =
        TextEditingController(text: total.toInt().toString());
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Proses Pembayaran'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bayar', style: TextStyle(fontSize: 16)),
                      Text(
                        currency.format(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metode pembayaran
                const Text('Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['CASH', 'QRIS', 'TRANSFER', 'DEBIT']
                      .map((method) => ChoiceChip(
                            label: Text(method),
                            selected: selectedMethod == method,
                            onSelected: (_) =>
                                setDialogState(() => selectedMethod = method),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: selectedMethod == method
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Nominal bayar
                const Text('Nominal Dibayar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),

                // Kembalian
                if (selectedMethod == 'CASH')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian'),
                        Text(
                          currency.format(
                            (double.tryParse(amountController.text) ?? 0) -
                                total,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 12),
                const Text('Catatan Transaksi (opsional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan catatan jika diperlukan...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
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
                final amountPaid = double.tryParse(amountController.text) ?? 0;
                if (amountPaid < total) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nominal bayar kurang!')),
                  );
                  return;
                }
                Navigator.pop(context);
                final success =
                    await ref.read(kasirProvider.notifier).processTransaction(
                          paymentMethod: selectedMethod,
                          amountPaid: amountPaid,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );
                if (success && context.mounted) {
                  _showSuccessDialog(context, ref);
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> tx) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final items = tx['items'] as List? ?? [];
    final date = DateTime.parse(tx['createdAt']);
    final formattedDate = DateFormat('dd-MM-yyyy HH:mm').format(date);

    pw.ImageProvider? logoImage;
    if (tx['outlet']?['logoUrl'] != null && (tx['outlet']?['logoUrl'] as String).isNotEmpty) {
      try {
        logoImage = await networkImage(tx['outlet']['logoUrl']);
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        width: 24,
                        height: 24,
                        child: pw.Image(logoImage),
                      ),
                    pw.Text(
                      tx['outlet']?['name']?.toString().toUpperCase() ?? 'APOTEK POS INDONESIA',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      tx['outlet']?['address']?.toString() ?? 'Jl. Sehat Selalu No. 99, Depok',
                      style: pw.TextStyle(fontSize: 5),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      tx['outlet']?['phone'] != null ? 'Telp: ${tx['outlet']['phone']}' : 'Telp: 021-98765432',
                      style: pw.TextStyle(fontSize: 5),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text('-------------------------------------', style: pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.Text('ID: ${tx['id'].toString().substring(0, 8)}', style: pw.TextStyle(fontSize: 6)),
              pw.Text('Tgl: $formattedDate', style: pw.TextStyle(fontSize: 6)),
              pw.Text('Apoteker: ${tx['cashier']?['name'] ?? 'Staff'}', style: pw.TextStyle(fontSize: 6)),
              pw.Text('-------------------------------------', style: pw.TextStyle(fontSize: 8)),
              
              // Items list
              ...items.map((item) {
                final drug = item['drug'] ?? {};
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${drug['name']}', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${item['quantity']} x ${currency.format(item['sellPrice'])}', style: pw.TextStyle(fontSize: 6)),
                        pw.Text(currency.format(item['subtotal']), style: pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  ],
                );
              }),
              
              pw.Text('-------------------------------------', style: pw.TextStyle(fontSize: 8)),
              
              // Calculations
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 6)),
                  pw.Text(currency.format(tx['subtotal'] ?? tx['totalAmount']), style: pw.TextStyle(fontSize: 6)),
                ],
              ),
              if (tx['discountAmount'] != null && (tx['discountAmount'] as num) > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Diskon:', style: pw.TextStyle(fontSize: 6)),
                    pw.Text('- ${currency.format(tx['discountAmount'])}', style: pw.TextStyle(fontSize: 6)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  pw.Text(currency.format(tx['totalAmount']), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bayar:', style: pw.TextStyle(fontSize: 6)),
                  pw.Text(currency.format(tx['amountPaid']), style: pw.TextStyle(fontSize: 6)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kembali:', style: pw.TextStyle(fontSize: 6)),
                  pw.Text(currency.format(tx['change']), style: pw.TextStyle(fontSize: 6)),
                ],
              ),
              if (tx['notes'] != null && (tx['notes'] as String).trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Catatan: ${tx['notes']}', style: pw.TextStyle(fontSize: 5, fontStyle: pw.FontStyle.italic)),
              ],
              pw.Text('-------------------------------------', style: pw.TextStyle(fontSize: 8)),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Terima Kasih', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    pw.Text('Semoga Lekas Sembuh', style: pw.TextStyle(fontSize: 6)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Struk_${tx['id'].toString().substring(0, 8)}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Dialog sukses transaksi
  void _showSuccessDialog(BuildContext context, WidgetRef ref) {
    final kasirState = ref.read(kasirProvider);
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final tx = kasirState.lastTransaction;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Transaksi Berhasil!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (tx != null) ...[
              Text('Total: ${currency.format(tx['totalAmount'])}'),
              Text('Kembalian: ${currency.format(tx['change'])}'),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: tx == null ? null : () => _printReceipt(tx),
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Struk'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(kasirProvider.notifier).clearCart();
                  },
                  child: const Text('Transaksi Baru'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftView(BuildContext context, WidgetRef ref) {
    final startBalanceCtrl = TextEditingController(text: '50000');
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.primary, size: 28),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Buka Laci Kasir',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Untuk memulai transaksi, masukkan nominal saldo awal laci uang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Saldo Awal Uang Laci (Rp)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: startBalanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Misal: 50000',
                  prefixText: 'Rp ',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Saldo awal wajib diisi';
                  if (double.tryParse(val) == null) return 'Harus angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Catatan (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Misal: modal kembalian pecahan 5rb & 10rb',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final val = double.parse(startBalanceCtrl.text);
                      final ok = await ref.read(shiftsProvider.notifier).openShift(val, notesCtrl.text.isEmpty ? null : notesCtrl.text);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Shift kasir berhasil dibuka! Selamat bertugas.'),
                          backgroundColor: AppTheme.success,
                        ));
                      }
                    }
                  },
                  child: const Text('Buka Kasir & Mulai Kerja', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCloseShiftDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> activeShift) {
    final endBalanceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tutup Shift Kasir'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anda akan menutup shift kasir saat ini. Silakan hitung uang tunai fisik yang ada di laci kasir dan masukkan nilainya.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow('Saldo Awal', currency.format(activeShift['startBalance'] ?? 0)),
                  _buildInfoRow('Waktu Buka', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(activeShift['startTime']))),
                  
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  const Text('Total Uang Fisik Laci (Rp)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: endBalanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan jumlah uang tunai fisik di laci',
                      prefixText: 'Rp ',
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Uang fisik wajib diisi';
                      if (double.tryParse(val) == null) return 'Harus angka valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Catatan Penutupan (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Misal: aman, tidak ada selisih',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final val = double.parse(endBalanceCtrl.text);
                  Navigator.pop(ctx); // close input dialog
                  
                  final result = await ref.read(shiftsProvider.notifier).closeShift(val, notesCtrl.text.isEmpty ? null : notesCtrl.text);
                  if (result != null && context.mounted) {
                    _showShiftSummaryDialog(context, result);
                  }
                }
              },
              child: const Text('Tutup Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftSummaryDialog(BuildContext context, Map<String, dynamic> shift) {
    final startBal = shift['startBalance'] ?? 0;
    final endBal = shift['endBalance'] ?? 0;
    final expectedBal = shift['expectedBalance'] ?? 0;
    final diff = shift['difference'] ?? 0;
    final totalSales = shift['totalSales'] ?? 0;
    final totalTx = shift['totalTransactions'] ?? 0;
    
    final diffColor = diff == 0
        ? AppTheme.success
        : diff < 0
            ? AppTheme.danger
            : Colors.amber.shade700;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Rekapitulasi Shift Kasir'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shift kasir Anda telah ditutup dengan sukses. Berikut ringkasan rekonsiliasi keuangan laci kasir:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Waktu Tutup', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
              _buildInfoRow('Total Transaksi', '$totalTx kali'),
              _buildInfoRow('Total Omzet Shift', currency.format(totalSales)),
              const Divider(),
              const SizedBox(height: 6),
              _buildInfoRow('Saldo Awal Laci', currency.format(startBal)),
              _buildInfoRow('Ekspektasi Laci', currency.format(expectedBal)),
              _buildInfoRow('Uang Fisik Laci', currency.format(endBal)),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selisih Keuangan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    currency.format(diff),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: diffColor),
                  ),
                ],
              ),
              if (diff < 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Peringatan: Terdapat minus uang di laci. Harap laporkan ke admin/pemilik.',
                          style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// Widget kartu obat — menggunakan DrugCategoryBadge
// ============================================================
class _DrugCard extends StatelessWidget {
  final DrugModel drug;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _DrugCard({
    required this.drug,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = drug.totalStock == 0;

    return InkWell(
      onTap: isOutOfStock ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOutOfStock ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama obat
            Text(
              drug.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isOutOfStock ? Colors.grey : AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // ✅ Badge kategori — ganti Container lama dengan DrugCategoryBadge
            DrugCategoryBadge(category: drug.category),

            const Spacer(),

            // Harga
            Text(
              currency.format(drug.sellPrice),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),

            // Stok
            Text(
              isOutOfStock ? 'Stok Habis' : 'Stok: ${drug.totalStock}',
              style: TextStyle(
                fontSize: 11,
                color: isOutOfStock ? AppTheme.danger : AppTheme.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Widget item di keranjang
// ============================================================
class _CartItemWidget extends StatelessWidget {
  final CartItem item;
  final NumberFormat currency;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;

  const _CartItemWidget({
    required this.item,
    required this.currency,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.drug.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Quantity control
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => onQuantityChanged(item.quantity - 1),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.remove, size: 16),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => onQuantityChanged(item.quantity + 1),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                currency.format(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
