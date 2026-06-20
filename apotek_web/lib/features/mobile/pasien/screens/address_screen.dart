import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  List<dynamic> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiClient.createDio().get('/addresses/my');
      setState(() {
        addresses = response.data as List? ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat alamat: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(String id) async {
    try {
      await ApiClient.createDio().delete('/addresses/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat berhasil dihapus'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus alamat: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _setDefaultAddress(String id) async {
    try {
      await ApiClient.createDio().patch('/addresses/$id', data: {
        'isDefault': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat utama berhasil diubah'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengatur alamat utama: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showAddEditAddressSheet({Map<String, dynamic>? addressToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditAddressForm(
        addressToEdit: addressToEdit,
        onSaved: () {
          Navigator.pop(context);
          _loadAddresses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alamat Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditAddressSheet(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 70, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada alamat pengiriman',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan alamat untuk pengiriman obat bebas',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addr = addresses[index];
                    final isDefault = addr['isDefault'] as bool? ?? false;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDefault ? AppTheme.primary : Colors.grey.shade200,
                          width: isDefault ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    addr['label'] ?? 'Rumah',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Alamat Utama',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                  onPressed: () => _showAddEditAddressSheet(addressToEdit: addr),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Hapus Alamat'),
                                        content: const Text('Apakah Anda yakin ingin menghapus alamat ini?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _deleteAddress(addr['id']);
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Text(
                              addr['recipientName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              addr['phone'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${addr['street']}, ${addr['city']}, ${addr['province']}, ${addr['postalCode']}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            ),
                            if (!isDefault) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 36),
                                  side: const BorderSide(color: AppTheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _setDefaultAddress(addr['id']),
                                child: const Text('Atur Sebagai Alamat Utama', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// Form Add/Edit Alamat dengan OpenStreetMap Autocomplete
class _AddEditAddressForm extends StatefulWidget {
  final Map<String, dynamic>? addressToEdit;
  final VoidCallback onSaved;

  const _AddEditAddressForm({this.addressToEdit, required this.onSaved});

  @override
  State<_AddEditAddressForm> createState() => _AddEditAddressFormState();
}

class _AddEditAddressFormState extends State<_AddEditAddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isSaving = false;
  bool _isDefault = false;
  
  List<dynamic> _osmSuggestions = [];
  bool _isSearchingOsm = false;

  @override
  void initState() {
    super.initState();
    if (widget.addressToEdit != null) {
      final addr = widget.addressToEdit!;
      _labelController.text = addr['label'] ?? '';
      _recipientController.text = addr['recipientName'] ?? '';
      _phoneController.text = addr['phone'] ?? '';
      _streetController.text = addr['street'] ?? '';
      _cityController.text = addr['city'] ?? '';
      _provinceController.text = addr['province'] ?? '';
      _postalCodeController.text = addr['postalCode'] ?? '';
      _isDefault = addr['isDefault'] as bool? ?? false;
    } else {
      _labelController.text = 'Rumah';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Cari Autocomplete Menggunakan OpenStreetMap Nominatim API
  Future<void> _searchOsmAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _osmSuggestions = []);
      return;
    }

    setState(() => _isSearchingOsm = true);
    try {
      final dio = Dio();
      // Nominatim membutuhkan User-Agent untuk term of use
      dio.options.headers['User-Agent'] = 'ApotekPOS-App';
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': 1,
          'limit': 5,
          'countrycodes': 'id', // Hanya Indonesia
        },
      );

      setState(() {
        _osmSuggestions = response.data as List? ?? [];
        _isSearchingOsm = false;
      });
    } catch (e) {
      setState(() => _isSearchingOsm = false);
    }
  }

  // Pilih Sugesti & Auto Populate Form
  void _selectOsmSuggestion(dynamic suggestion) {
    final addr = suggestion['address'] as Map<String, dynamic>? ?? {};
    final displayName = suggestion['display_name'] as String? ?? '';
    
    // Extract jalan/rute
    final road = addr['road'] as String? ?? addr['suburb'] as String? ?? addr['village'] as String? ?? displayName.split(',').first;
    // Extract kota
    final city = addr['city'] as String? ?? addr['town'] as String? ?? addr['city_district'] as String? ?? addr['municipality'] as String? ?? '';
    // Extract provinsi
    final province = addr['state'] as String? ?? '';
    // Extract kode pos
    final postcode = addr['postcode'] as String? ?? '';

    setState(() {
      _streetController.text = road;
      _cityController.text = city;
      _provinceController.text = province;
      _postalCodeController.text = postcode;
      _osmSuggestions = [];
      _searchController.clear();
    });
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final data = {
      'label': _labelController.text.trim(),
      'recipientName': _recipientController.text.trim(),
      'phone': _phoneController.text.trim(),
      'street': _streetController.text.trim(),
      'city': _cityController.text.trim(),
      'province': _provinceController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
      'isDefault': _isDefault,
    };

    try {
      final dio = ApiClient.createDio();
      if (widget.addressToEdit != null) {
        // Edit mode
        await dio.patch('/addresses/${widget.addressToEdit!['id']}', data: data);
      } else {
        // Add mode
        await dio.post('/addresses', data: data);
      }
      
      widget.onSaved();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan alamat: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.addressToEdit != null ? 'Edit Alamat' : 'Tambah Alamat Baru',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              
              // === AUTOCMPLETE SEARCH FIELD ===
              const Text('Cari Alamat (OpenStreetMap Autocomplete)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 6),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ketik nama jalan / gedung...',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: _isSearchingOsm 
                      ? const SizedBox(width: 18, height: 18, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                      : _searchController.text.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchController.clear()))
                          : null,
                ),
                onChanged: _searchOsmAddress,
              ),
              
              // OSM suggestions list
              if (_osmSuggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _osmSuggestions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _osmSuggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: AppTheme.primary, size: 18),
                        title: Text(item['display_name'] ?? '', style: const TextStyle(fontSize: 12)),
                        onTap: () => _selectOsmSuggestion(item),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              
              // Form Fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(labelText: 'Label (Rumah/Kantor/dll)'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isDefault,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() => _isDefault = v ?? false),
                        ),
                        const Expanded(child: Text('Alamat Utama', style: TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _recipientController,
                decoration: const InputDecoration(labelText: 'Nama Penerima'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Nomor Telepon Penerima'),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Alamat Jalan / Gedung'),
                maxLines: 2,
                validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Kota/Kabupaten'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _provinceController,
                      decoration: const InputDecoration(labelText: 'Provinsi'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _postalCodeController,
                decoration: const InputDecoration(labelText: 'Kode Pos'),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      onPressed: _saveAddress,
                      child: Text(widget.addressToEdit != null ? 'Simpan Alamat' : 'Tambahkan Alamat'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
