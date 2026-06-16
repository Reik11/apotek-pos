import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/kasir_provider.dart';
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
                      const Text(
                        'Kasir',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            currency.format(kasirState.totalAmount),
                            style: const TextStyle(
                              fontSize: 20,
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
          SizedBox(
            width: double.infinity,
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
