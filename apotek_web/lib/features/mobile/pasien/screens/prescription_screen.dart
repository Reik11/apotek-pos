import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class PrescriptionScreen extends ConsumerStatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  final _notesController = TextEditingController();
  final _customUrlController = TextEditingController();
  
  List<dynamic> prescriptions = [];
  bool isLoading = true;
  bool isUploading = false;
  File? _selectedImage;
  bool _useCustomUrl = false;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiClient.createDio().get('/prescriptions/my');
      setState(() {
        prescriptions = response.data as List? ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat resep: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  Future<void> _submitPrescription() async {
    if (_selectedImage == null && (!_useCustomUrl || _customUrlController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih gambar resep atau gunakan URL kustom'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      // Simulasi upload gambar ke storage (2 detik)
      await Future.delayed(const Duration(seconds: 2));

      // Jika menggunakan link kustom, pakai input user, jika tidak gunakan mock prescription URL
      final imageUrl = _useCustomUrl && _customUrlController.text.trim().isNotEmpty
          ? _customUrlController.text.trim()
          : 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=800&q=80';

      await ApiClient.createDio().post('/prescriptions', data: {
        'imageUrl': imageUrl,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resep berhasil diunggah! Menunggu verifikasi apoteker.'),
            backgroundColor: AppTheme.success,
          ),
        );
        
        // Reset form
        setState(() {
          _selectedImage = null;
          _notesController.clear();
          _customUrlController.clear();
          _useCustomUrl = false;
        });

        // Reload data
        _loadPrescriptions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah resep: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resep Dokter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload resep dokter Anda agar apoteker dapat memverifikasi obat Anda.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          
          // Form Upload & List Tabs
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade600,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: 'Upload Resep'),
                        Tab(text: 'Riwayat Resep'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildUploadFormTab(),
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFormTab() {
    return SingleChildScrollView(
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Foto Resep',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              
              // Image Picker Area
              if (!_useCustomUrl)
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Kamera'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Galeri'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Sentuh untuk mengambil/memilih foto resep', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                  ),
                ),

              // Custom URL Checkbox & TextField for Testing (Optional)
              Row(
                children: [
                  Checkbox(
                    value: _useCustomUrl,
                    activeColor: AppTheme.primary,
                    onChanged: (v) {
                      setState(() {
                        _useCustomUrl = v ?? false;
                        if (!_useCustomUrl) _selectedImage = null;
                      });
                    },
                  ),
                  const Text('Gunakan URL Kustom untuk testing', style: TextStyle(fontSize: 12)),
                ],
              ),
              if (_useCustomUrl)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _customUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL Gambar Resep',
                      hintText: 'https://example.com/resep.jpg',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Text(
                'Catatan untuk Apoteker (Opsional)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tuliskan instruksi khusus atau catatan untuk apoteker...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              isUploading
                  ? const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Sedang mengunggah resep...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppTheme.primary,
                      ),
                      onPressed: _submitPrescription,
                      child: const Text('Unggah Resep Dokter'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (prescriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Belum ada resep yang diunggah', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Semua riwayat unggahan resep Anda akan muncul di sini', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: prescriptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = prescriptions[index];
        final status = item['status'] as String? ?? 'PENDING';
        final notes = item['notes'] as String? ?? '';
        final date = DateTime.parse(item['createdAt']);
        final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);

        Color statusColor = AppTheme.warning;
        String statusLabel = 'Menunggu Verifikasi';
        if (status == 'VERIFIED') {
          statusColor = AppTheme.success;
          statusLabel = 'Resep Disetujui';
        } else if (status == 'REJECTED') {
          statusColor = AppTheme.danger;
          statusLabel = 'Ditolak';
        }

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prescription Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item['imageUrl'] as String? ?? 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=100&q=80',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Prescription Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notes.isNotEmpty ? notes : 'Tanpa catatan',
                        style: TextStyle(
                          fontSize: 13,
                          color: notes.isNotEmpty ? AppTheme.textPrimary : Colors.grey,
                          fontStyle: notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
