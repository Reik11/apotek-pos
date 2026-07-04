import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/outlets/providers/outlets_provider.dart';
import '../../profile/profile_screen.dart';
import 'prescription_screen.dart';
import 'address_screen.dart';

class PasienHomeScreen extends ConsumerStatefulWidget {
  const PasienHomeScreen({super.key});

  @override
  ConsumerState<PasienHomeScreen> createState() => _PasienHomeScreenState();
}

class _PasienHomeScreenState extends ConsumerState<PasienHomeScreen> {
  final _searchController = TextEditingController();
  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  List<dynamic> allDrugs = [];
  List<dynamic> searchResults = [];
  List<dynamic> cartItems = [];
  List<dynamic> savedAddresses = [];
  String? _selectedAddressId;
  
  double shippingFee = 0;
  String _paymentMethod = 'TRANSFER'; // 'CASH', 'TRANSFER', 'QRIS'
  String? _selectedPrescriptionId;
  List<dynamic> verifiedPrescriptions = [];
  
  bool isSearching = false;
  bool isLoadingHome = true;
  int _currentIndex = 0;
  String _deliveryMethod = 'PICKUP'; // 'PICKUP' atau 'DELIVERY'
  bool get _cartHasRxDrug => cartItems.any((item) => item['drug']['requiresPrescription'] == true);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final outletState = ref.read(outletsProvider);
      final outletId = outletState.selectedOutlet?['id'];
      final drugUrl = outletId != null ? '/drugs?outletId=$outletId' : '/drugs';

      final response = await ApiClient.createDio().get(drugUrl);
      final addrResponse = await ApiClient.createDio().get('/addresses/my');
      final rxResponse = await ApiClient.createDio().get('/prescriptions/my');
      if (mounted) {
        setState(() {
          allDrugs = response.data as List? ?? [];
          savedAddresses = addrResponse.data as List? ?? [];
          
          final rxList = rxResponse.data as List? ?? [];
          verifiedPrescriptions = rxList.where((rx) {
            final isVerified = rx['status'] == 'VERIFIED';
            final hasNoOrders = rx['orders'] == null || (rx['orders'] as List).isEmpty;
            return isVerified && hasNoOrders;
          }).toList();
          
          // Set default address
          if (savedAddresses.isNotEmpty) {
            final defaultAddr = savedAddresses.firstWhere(
              (addr) => addr['isDefault'] == true,
              orElse: () => savedAddresses.first,
            );
            _selectedAddressId = defaultAddr['id'];
          } else {
            _selectedAddressId = null;
          }
          isLoadingHome = false;
        });
        _updateShippingFee();
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingHome = false);
    }
  }

  Future<void> _updateShippingFee() async {
    if (_deliveryMethod != 'DELIVERY') {
      setState(() {
        shippingFee = 0;
      });
      return;
    }

    if (_paymentMethod == 'CASH') {
      setState(() {
        _paymentMethod = 'TRANSFER';
      });
    }

    if (_selectedAddressId == null) {
      setState(() {
        shippingFee = 0;
      });
      return;
    }

    final selectedAddr = savedAddresses.firstWhere((addr) => addr['id'] == _selectedAddressId, orElse: () => null);
    if (selectedAddr == null) return;
    try {
      final res = await ApiClient.createDio().get('/orders/shipping-fee?city=${selectedAddr['city']}');
      setState(() {
        shippingFee = (res.data['fee'] as num).toDouble();
      });
    } catch (e) {
      setState(() {
        shippingFee = 15000; // fallback
      });
    }
  }

  Future<void> _searchDrugs(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }
    setState(() => isSearching = true);
    try {
      final outletState = ref.read(outletsProvider);
      final outletId = outletState.selectedOutlet?['id'];
      final searchUrl = outletId != null ? '/drugs?search=$query&outletId=$outletId' : '/drugs?search=$query';
      final response = await ApiClient.createDio().get(searchUrl);
      setState(() {
        searchResults = response.data as List? ?? [];
        isSearching = false;
      });
    } catch (e) {
      setState(() => isSearching = false);
    }
  }

  void _addToCart(Map<String, dynamic> drug) {
    // Blokir obat resep dari ditambahkan ke keranjang langsung
    if (drug['requiresPrescription'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.medical_services, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Obat Resep Dokter'),
          ]),
          content: const Text(
            'Obat ini memerlukan resep dokter. Silakan datang langsung ke apotek dengan membawa resep Anda, atau upload resep terlebih dahulu melalui tab Resep.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }

    final existing = cartItems.indexWhere((item) => item['drug']['id'] == drug['id']);
    setState(() {
      if (existing >= 0) {
        cartItems[existing]['quantity']++;
      } else {
        cartItems.add({'drug': drug, 'quantity': 1});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${drug['name']} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double get totalCart => cartItems.fold(
      0,
      (sum, item) =>
          sum +
          (item['drug']['sellPrice'] as num).toDouble() *
              (item['quantity'] as int));

  // ─── Tampilkan popup konfirmasi data diri sebelum checkout ───
  void _checkout() {
    if (cartItems.isEmpty) return;
    _showMedicalConfirmationDialog();
  }

  Future<void> _showMedicalConfirmationDialog() async {
    // Load data medis pasien saat ini dari backend
    Map<String, dynamic>? medicalData;
    try {
      final res = await ApiClient.createDio().get('/users/medical-profile');
      medicalData = Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      medicalData = {};
    }

    // State lokal popup
    final weightCtrl = TextEditingController(
      text: medicalData?['weight']?.toString() ?? '',
    );
    final heightCtrl = TextEditingController(
      text: medicalData?['height']?.toString() ?? '',
    );
    bool isPregnant     = medicalData?['isPregnant'] as bool? ?? false;
    bool isBreastfeeding = medicalData?['isBreastfeeding'] as bool? ?? false;
    bool hasNewMed      = false;
    bool hasNewAllergy  = false;

    // Kalkulasi usia otomatis dari birthDate
    String ageText = '—';
    if (medicalData?['birthDate'] != null) {
      final birth = DateTime.tryParse(medicalData!['birthDate']);
      if (birth != null) {
        final age = DateTime.now().difference(birth).inDays ~/ 365;
        ageText = '$age tahun';
      }
    }
    final birthText = medicalData?['birthDate'] != null
        ? _formatDate(medicalData!['birthDate'])
        : '—';

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_outlined, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Konfirmasi data diri',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Pastikan data berikut masih sesuai kondisimu saat ini.',
                              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── DATA FISIK ──
                  const Text('DATA FISIK', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Usia (otomatis, readonly)
                      Expanded(
                        child: _medInfoTile(
                          label: 'Usia',
                          value: ageText,
                          sub: 'Lahir $birthText',
                          badge: 'Otomatis',
                          badgeColor: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tanggal lahir (readonly)
                      Expanded(
                        child: _medInfoTile(
                          label: 'Tanggal lahir',
                          value: birthText,
                          sub: 'Hubungi apotek jika salah',
                          badge: '🔒 Tetap',
                          badgeColor: const Color(0xFF48484A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Berat badan (editable)
                      Expanded(
                        child: _medEditTile(
                          label: 'Berat badan',
                          suffix: 'kg',
                          controller: weightCtrl,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tinggi badan (editable)
                      Expanded(
                        child: _medEditTile(
                          label: 'Tinggi badan',
                          suffix: 'cm',
                          controller: heightCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── KONDISI SAAT INI ──
                  const Text('KONDISI SAAT INI', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _conditionToggle(
                          label: 'Sedang hamil',
                          icon: null,
                          value: isPregnant,
                          onChanged: (v) => setDialogState(() => isPregnant = v),
                          isLast: false,
                        ),
                        _conditionToggle(
                          label: 'Sedang menyusui',
                          icon: Icons.child_friendly_outlined,
                          value: isBreastfeeding,
                          onChanged: (v) => setDialogState(() => isBreastfeeding = v),
                          isLast: false,
                        ),
                        _conditionToggle(
                          label: 'Ada obat rutin baru',
                          icon: Icons.medication_outlined,
                          value: hasNewMed,
                          onChanged: (v) => setDialogState(() => hasNewMed = v),
                          isLast: false,
                        ),
                        _conditionToggle(
                          label: 'Ada alergi baru',
                          icon: Icons.warning_amber_outlined,
                          value: hasNewAllergy,
                          onChanged: (v) => setDialogState(() => hasNewAllergy = v),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Catatan privasi ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.lock_outline, color: Color(0xFF8E8E93), size: 13),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Data hanya digunakan untuk validasi dosis dan keamanan obat oleh apoteker.',
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Tombol aksi ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF48484A)),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Lewati'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showPaymentDialog();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Data sudah benar'),
                          onPressed: () async {
                            // Simpan data yang diubah ke backend
                            try {
                              await ApiClient.createDio().put('/users/medical-profile', data: {
                                'weight': double.tryParse(weightCtrl.text),
                                'height': double.tryParse(heightCtrl.text),
                                'isPregnant': isPregnant,
                                'isBreastfeeding': isBreastfeeding,
                              });
                            } catch (_) {}
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showPaymentDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '—';
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _medInfoTile({
    required String label,
    required String value,
    required String sub,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _medEditTile({required String label, required String suffix, required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(suffix, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conditionToggle({
    required String label,
    required IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF8E8E93), size: 18),
                const SizedBox(width: 10),
              ] else
                const SizedBox(width: 28),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 14, endIndent: 14),
      ],
    );
  }

  // ─── Modal pembayaran (dipanggil setelah konfirmasi data diri) ───
  void _showPaymentDialog() {
    if (_paymentMethod == 'CASH') {
      _processCheckout(null);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? mockProofUrl;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Pembayaran (Simulasi Midtrans)'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pembayaran:', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(
                    currency.format(totalCart),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  if (_paymentMethod == 'TRANSFER') ...[
                    const Text('Silakan transfer ke rekening berikut:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank BCA: 1234567890', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('a.n. Apotek POS Indonesia'),
                          SizedBox(height: 4),
                          Text('Bank Mandiri: 9876543210', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('a.n. Apotek POS Indonesia'),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text('Silakan scan QRIS berikut:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.network(
                          'https://api.dicebear.com/7.x/bottts/svg?seed=qris_mock',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Bukti Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (mockProofUrl == null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                        side: const BorderSide(color: AppTheme.primary),
                        foregroundColor: AppTheme.primary,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          mockProofUrl = 'https://api.dicebear.com/7.x/bottts/svg?seed=proof_${DateTime.now().millisecondsSinceEpoch}';
                        });
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Simulasikan Unggah Bukti Bayar'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.success),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Bukti pembayaran diunggah', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                            onPressed: () {
                              setDialogState(() { mockProofUrl = null; });
                            },
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
                onPressed: mockProofUrl == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _processCheckout(mockProofUrl);
                      },
                child: const Text('Konfirmasi & Selesaikan'),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _processCheckout(String? paymentProof) async {
    try {
      final items = cartItems
          .map((item) => {
                'drugId': item['drug']['id'],
                'quantity': item['quantity'],
              })
          .toList();

      final outletState = ref.read(outletsProvider);
      final outletId = outletState.selectedOutlet?['id'];

      final response = await ApiClient.createDio().post('/orders', data: {
        'items': items,
        'deliveryMethod': _deliveryMethod,
        'addressId': _deliveryMethod == 'DELIVERY' ? _selectedAddressId : null,
        'prescriptionId': _selectedPrescriptionId,
        'shippingFee': shippingFee,
        'paymentMethod': _paymentMethod,
        'paymentProof': paymentProof,
        'outletId': outletId,
      });

      final order = response.data;
      setState(() {
        cartItems = [];
        _selectedPrescriptionId = null;
      });
      _loadInitialData();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Pesanan Berhasil! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
                const SizedBox(height: 16),
                const Text('Kode Pesanan:', style: TextStyle(color: AppTheme.textSecondary)),
                Text(
                  order['orderCode'],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _deliveryMethod == 'DELIVERY'
                        ? AppTheme.primary.withOpacity(0.08)
                        : AppTheme.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _deliveryMethod == 'DELIVERY'
                            ? Icons.local_shipping_outlined
                            : Icons.store_outlined,
                        color: _deliveryMethod == 'DELIVERY' ? AppTheme.primary : AppTheme.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _deliveryMethod == 'DELIVERY'
                              ? 'Pesanan akan diantar ke alamat Anda'
                              : 'Silakan ambil di apotek dengan menunjukkan kode ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: _deliveryMethod == 'DELIVERY' ? AppTheme.primary : AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat order'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final outletState = ref.watch(outletsProvider);

    if (outletState.selectedOutlet == null) {
      return _buildOutletSelectionScreen(outletState);
    }
    
    final List<Widget> pages = [
      _buildHomeTab(),
      _buildCartTab(),
      PrescriptionScreen(
        onRedeemPrescription: (rx) {
          final prescribed = rx['prescribedDrugs'] as List? ?? [];
          setState(() {
            _selectedPrescriptionId = rx['id'];
            cartItems = prescribed.map((item) {
              final localDrug = allDrugs.firstWhere((d) => d['id'] == item['drugId'], orElse: () => null);
              return {
                'drug': localDrug ?? {
                  'id': item['drugId'],
                  'name': item['name'],
                  'sellPrice': item['sellPrice'],
                  'requiresPrescription': true,
                  'category': 'KERAS',
                },
                'quantity': item['quantity'] as int,
              };
            }).toList();
            _deliveryMethod = 'PICKUP';
            _currentIndex = 1; // Pindah ke tab keranjang
          });
          _updateShippingFee();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resep berhasil dimuat ke keranjang!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _buildHistoryTab(),
      const ProfileScreen(isFromBottomNav: true),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            color: AppTheme.background,
            child: Column(
              children: [
                _buildHeader(user?.name ?? 'Pasien'),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: pages[_currentIndex],
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    final outletState = ref.watch(outletsProvider);
    final selectedOutletName = outletState.selectedOutlet?['name'] ?? 'Pilih Cabang';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: _currentIndex == 4
            ? null
            : const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $userName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mau cari obat apa hari ini?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ref.read(outletsProvider.notifier).selectOutlet(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            selectedOutletName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_location_outlined, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded),
                if (cartItems.isNotEmpty)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Keranjang',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Resep',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Riwayat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final isSearchingMode = _searchController.text.isNotEmpty;

    return Column(
      children: [
        Transform.translate(
          offset: const Offset(0, -20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama obat atau gejala...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                  suffixIcon: isSearchingMode 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _searchDrugs('');
                          },
                        ) 
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: _searchDrugs,
              ),
            ),
          ),
        ),
        
        Expanded(
          child: isSearchingMode
              ? _buildSearchResults()
              : _buildInteractiveDashboard(),
        ),
      ],
    );
  }

  // === INTERACTIVE DASHBOARD (NEW) ===
  Widget _buildInteractiveDashboard() {
    if (isLoadingHome) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Promo Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage(
                      'https://images.unsplash.com/photo-1576602976047-174e57a47881?auto=format&fit=crop&q=80&w=800&h=300'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.9),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Promo Sehat\nKeluarga',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Diskon s/d 50% Vitamin',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 2. Kategori Cepat
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Kategori Utama',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryItem(Icons.medication, 'Obat Resep', AppTheme.danger),
                _buildCategoryItem(Icons.vaccines, 'Obat Bebas', AppTheme.success),
                _buildCategoryItem(Icons.health_and_safety, 'Vitamin', AppTheme.warning),
                _buildCategoryItem(Icons.medical_services, 'P3K', AppTheme.info),
                _buildCategoryItem(Icons.spa, 'Herbal', Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 3. Rekomendasi Obat (Horizontal List)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rekomendasi Hari Ini',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {}, // Future: Lihat Semua
                  child: const Text('Lihat Semua'),
                )
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: allDrugs.isEmpty
                ? const Center(child: Text('Belum ada data obat.'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allDrugs.length > 5 ? 5 : allDrugs.length,
                    itemBuilder: (context, index) {
                      final drug = allDrugs[index];
                      return _buildDrugCard(drug);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    return Container(
      width: 76,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildDrugCard(Map<String, dynamic> drug) {
    final batches = drug['batches'] as List? ?? [];
    final totalStock = batches.fold<int>(0, (sum, b) => sum + (b['stock'] as int));

    // Pilih placeholder image berdasarkan ID untuk variasi
    final imageSeed = drug['id'].hashCode % 3 + 1;
    final imageUrl = imageSeed == 1 
        ? 'https://images.unsplash.com/photo-1584308666744-24d5e4a42828?auto=format&fit=crop&q=80&w=200&h=200'
        : imageSeed == 2 
        ? 'https://images.unsplash.com/photo-1550572017-edb923f03b22?auto=format&fit=crop&q=80&w=200&h=200'
        : 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&q=80&w=200&h=200';

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Obat
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Info Obat
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    drug['category'],
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(drug['sellPrice']),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: totalStock > 0 ? () => _addToCart(drug) : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(totalStock > 0 ? '+ Tambah' : 'Habis',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === HASIL PENCARIAN (Lama) ===
  Widget _buildSearchResults() {
    if (isSearching) return const Center(child: CircularProgressIndicator());
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Obat tidak ditemukan', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final drug = searchResults[index];
        final batches = drug['batches'] as List? ?? [];
        final totalStock = batches.fold<int>(0, (sum, b) => sum + (b['stock'] as int));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1550572017-edb923f03b22?auto=format&fit=crop&q=80&w=200&h=200'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(drug['sellPrice']),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    totalStock > 0 ? 'Stok: $totalStock' : 'Habis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: totalStock > 0 ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: totalStock > 0 ? () => _addToCart(drug) : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('+ Tambah', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- KODE KERANJANG DAN RIWAYAT SAMA SEPERTI SEBELUMNYA ---
  Widget _buildCartTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Keranjang Belanja',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (verifiedPrescriptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ada Resep Terverifikasi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPrescriptionId,
                    hint: const Text('Pilih resep untuk dimuat', style: TextStyle(fontSize: 12)),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: verifiedPrescriptions.map((rx) {
                      return DropdownMenuItem<String>(
                        value: rx['id'],
                        child: Text(
                          'Resep #${rx['id'].toString().substring(0, 8)} (${DateFormat('dd MMM').format(DateTime.parse(rx['createdAt']))})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final rx = verifiedPrescriptions.firstWhere((r) => r['id'] == val);
                      final prescribed = rx['prescribedDrugs'] as List? ?? [];
                      
                      setState(() {
                        _selectedPrescriptionId = val;
                        cartItems = prescribed.map((item) {
                          final localDrug = allDrugs.firstWhere((d) => d['id'] == item['drugId'], orElse: () => null);
                          return {
                            'drug': localDrug ?? {
                              'id': item['drugId'],
                              'name': item['name'],
                              'sellPrice': item['sellPrice'],
                              'requiresPrescription': true,
                              'category': 'KERAS',
                            },
                            'quantity': item['quantity'] as int,
                          };
                        }).toList();
                        _deliveryMethod = 'PICKUP';
                      });
                      _updateShippingFee();
                    },
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Keranjang Anda masih kosong',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() {
                          _currentIndex = 0;
                          _searchController.clear();
                        }),
                        child: const Text('Mulai Cari Obat'),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['drug']['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(item['drug']['sellPrice']),
                                  style: const TextStyle(
                                      color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: () => setState(() {
                                    if (item['quantity'] > 1) {
                                      item['quantity']--;
                                    } else {
                                      cartItems.removeAt(index);
                                      if (cartItems.isEmpty) {
                                        _selectedPrescriptionId = null;
                                      }
                                    }
                                  }),
                                ),
                                Text(
                                  '${item['quantity']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed: () =>
                                      setState(() => item['quantity']++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (cartItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Metode Pengambilan ---
                const Text('Metode Pengambilan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _deliveryMethod = 'PICKUP');
                          _updateShippingFee();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _deliveryMethod == 'PICKUP'
                                ? AppTheme.primary
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _deliveryMethod == 'PICKUP'
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.store_outlined,
                                  color: _deliveryMethod == 'PICKUP'
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(height: 4),
                              Text('Ambil Sendiri',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _deliveryMethod == 'PICKUP'
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _cartHasRxDrug
                            ? null
                            : () {
                                setState(() => _deliveryMethod = 'DELIVERY');
                                _updateShippingFee();
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _cartHasRxDrug
                                ? Colors.grey.shade200
                                : _deliveryMethod == 'DELIVERY'
                                    ? AppTheme.primary
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _cartHasRxDrug
                                  ? Colors.grey.shade300
                                  : _deliveryMethod == 'DELIVERY'
                                      ? AppTheme.primary
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  color: _cartHasRxDrug
                                      ? Colors.grey.shade400
                                      : _deliveryMethod == 'DELIVERY'
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(height: 4),
                              Text('Antar ke Rumah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _cartHasRxDrug
                                        ? Colors.grey.shade400
                                        : _deliveryMethod == 'DELIVERY'
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_cartHasRxDrug)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 13, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Obat resep hanya bisa diambil langsung di apotek',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // --- Pilihan Alamat Pengiriman ---
                if (_deliveryMethod == 'DELIVERY') ...[
                  const Text('Alamat Pengiriman',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (savedAddresses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Anda belum memiliki alamat pengiriman.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.danger),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 36),
                              backgroundColor: AppTheme.primary,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddressScreen()),
                              );
                              _loadInitialData(); // Reload addresses after return
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah Alamat Baru', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pilih Alamat:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AddressScreen()),
                                  );
                                  _loadInitialData(); // Reload addresses after return
                                },
                                child: const Text('Kelola Alamat', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          DropdownButtonFormField<String>(
                            value: _selectedAddressId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: savedAddresses.map((addr) {
                              return DropdownMenuItem<String>(
                                value: addr['id'],
                                child: Text(
                                  '[${addr['label']}] ${addr['street']}, ${addr['city']}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAddressId = val;
                              });
                              _updateShippingFee();
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // --- Pilihan Metode Pembayaran ---
                const Text('Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_deliveryMethod == 'PICKUP') ...[
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Bayar di Apotek', style: TextStyle(fontSize: 10))),
                          selected: _paymentMethod == 'CASH',
                          onSelected: (val) => setState(() => _paymentMethod = 'CASH'),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: _paymentMethod == 'CASH' ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Transfer Bank', style: TextStyle(fontSize: 10))),
                        selected: _paymentMethod == 'TRANSFER',
                        onSelected: (val) => setState(() => _paymentMethod = 'TRANSFER'),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: _paymentMethod == 'TRANSFER' ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('QRIS', style: TextStyle(fontSize: 10))),
                        selected: _paymentMethod == 'QRIS',
                        onSelected: (val) => setState(() => _paymentMethod = 'QRIS'),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: _paymentMethod == 'QRIS' ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- Total & Tombol Buat Pesanan ---
                if (_deliveryMethod == 'DELIVERY') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Biaya Pengiriman',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      Text(
                        currency.format(shippingFee),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    Text(
                      currency.format(totalCart),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_deliveryMethod == 'DELIVERY' && _selectedAddressId == null) ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _deliveryMethod == 'DELIVERY'
                              ? Icons.local_shipping_outlined
                              : Icons.store_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _deliveryMethod == 'DELIVERY' ? 'Pesan & Antar' : 'Buat Pesanan',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: ApiClient.createDio().get('/orders/my-orders'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data?.data as List? ?? [];

              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Belum ada riwayat order', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final status = order['status'] as String;

                  Color statusColor;
                  switch (status) {
                    case 'PENDING':
                      statusColor = AppTheme.warning;
                      break;
                    case 'READY':
                      statusColor = AppTheme.success;
                      break;
                    case 'COMPLETED':
                      statusColor = Colors.grey;
                      break;
                    default:
                      statusColor = AppTheme.primaryLight;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kode Order',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  Text(
                                    order['orderCode'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Belanja', style: TextStyle(color: AppTheme.textSecondary)),
                            Text(
                              currency.format(order['totalAmount']),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (status == 'READY')
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: AppTheme.success, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Pesanan Anda sudah siap! Silakan tunjukkan kode order di kasir.',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutletSelectionScreen(OutletsState state) {
    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Terjadi kesalahan: ${state.error}',
                style: const TextStyle(color: AppTheme.danger),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(outletsProvider.notifier).loadOutlets(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final outlets = state.outlets;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Cabang Apotek',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pilih apotek untuk belanja obat & tebus resep',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: outlets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, size: 64, color: AppTheme.textHint),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada cabang apotek terdaftar.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: outlets.length,
                        separatorBuilder: (ctx, index) => const SizedBox(height: 16),
                        itemBuilder: (ctx, index) {
                          final outlet = outlets[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: AppTheme.border.withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                ref.read(outletsProvider.notifier).selectOutlet(outlet);
                                _loadInitialData(); // Reload drugs for selected outlet
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            outlet['name'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 16,
                                                color: AppTheme.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  outlet['address'] ?? '-',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (outlet['phone'] != null && (outlet['phone'] as String).isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 16,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  outlet['phone'],
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
}
