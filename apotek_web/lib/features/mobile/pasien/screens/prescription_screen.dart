import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart' as dio;
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/providers/auth_provider.dart';




class PrescriptionScreen extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onRedeemPrescription;

  const PrescriptionScreen({
    super.key,
    this.onRedeemPrescription,
  });

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
  Uint8List? _webImageBytes;
  String? _webImageName;
  bool _useCustomUrl = false;

  // Variabel OCR
  String _ocrText = '';
  List<Map<String, dynamic>> _detectedDrugs = [];
  bool _isOcrProcessing = false;
  bool _isUploadingPurchase = false;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);



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
      final token = ref.read(authProvider).token;
      final response = await ApiClient.createDio(token: token).get('/prescriptions/my');
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
    if (!kIsWeb && source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin kamera diperlukan untuk memotret resep!'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return;
      }
    }

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _webImageName = pickedFile.name;
          _selectedImage = File(pickedFile.path); // path placeholder
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _webImageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }


  Future<void> _processImageOcr() async {
    final hasImage = _selectedImage != null || _webImageBytes != null;
    if (!hasImage) return;

    setState(() {
      _isOcrProcessing = true;
      _ocrText = '';
      _detectedDrugs = [];
    });

    try {
      if (kIsWeb) {
        final token = ref.read(authProvider).token;
        final dioClient = ApiClient.createDio(token: token);
        final dio.FormData formData = dio.FormData();
        
        formData.files.add(MapEntry(
          'file',
          dio.MultipartFile.fromBytes(
            _webImageBytes!,
            filename: _webImageName ?? 'prescription.jpg',
          ),
        ));

        final response = await dioClient.post(
          '/external/ocr-prescription',
          data: formData,
        );

        final String detectedText = response.data['rawText'] ?? '';
        setState(() {
          _ocrText = detectedText;
        });

        await _analyzeDrugsOcr(detectedText);
      } else {
        final inputImage = InputImage.fromFilePath(_selectedImage!.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        await textRecognizer.close();

        final String detectedText = recognizedText.text;
        setState(() {
          _ocrText = detectedText;
        });

        if (detectedText.trim().isEmpty) {
          setState(() => _isOcrProcessing = false);
          return;
        }

        await _analyzeDrugsOcr(detectedText);
      }
    } catch (e) {
      setState(() => _isOcrProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses OCR: $e')),
        );
      }
    }
  }

  Future<void> _analyzeDrugsOcr(String text) async {
    try {
      final token = ref.read(authProvider).token;
      final response = await ApiClient.createDio(token: token).post(
        '/external/ocr-analyze',
        data: {'text': text},
      );

      setState(() {
        _detectedDrugs = List<Map<String, dynamic>>.from(response.data['drugs'] ?? []);
        _isOcrProcessing = false;
      });
    } catch (e) {
      await _parseManuallyOcr(text);
    }
  }

  Future<void> _parseManuallyOcr(String text) async {
    final lines = text.split('\n');
    final drugs = <Map<String, dynamic>>[];
    final token = ref.read(authProvider).token;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final response = await ApiClient.createDio(token: token).get(
            '/external/rxnorm/search?name=${Uri.encodeComponent(line.trim())}');

        final results = response.data as List? ?? [];
        if (results.isNotEmpty) {
          final localResponse = await ApiClient.createDio(token: token)
              .get('/drugs?search=${Uri.encodeComponent(line.trim())}');
          final localDrugs = localResponse.data as List? ?? [];

          drugs.add({
            'detectedName': line.trim(),
            'rxnorm': results.first,
            'localDrugs': localDrugs,
          });
        }
      } catch (e) {
        continue;
      }
    }

    setState(() {
      _detectedDrugs = drugs;
      _isOcrProcessing = false;
    });
  }

  void _showJustInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Informasi Kandungan Obat'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hasil scan ini hanya digunakan untuk pencarian informasi kandungan obat (tidak diajukan ke Apoteker).',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ..._detectedDrugs.map((drug) {
                  final name = drug['detectedName'] ?? '-';
                  final localDrugs = drug['localDrugs'] as List? ?? [];
                  final localDrug = localDrugs.isNotEmpty ? localDrugs.first : null;
                  
                  final genericName = localDrug?['genericName'] ?? localDrug?['activeIngredient'] ?? drug['rxnorm']?['name'] ?? 'Kandungan Umum';
                  final category = localDrug?['category'] ?? 'BEBAS';
                  final type = localDrug?['type'] ?? 'GENERIK';
                  
                  final fdaIndications = localDrug?['fdaIndications'] ?? localDrug?['description'] ?? 'Informasi kegunaan klinis belum disinkronkan.';
                  final fdaSideEffects = localDrug?['fdaSideEffects'] ?? 'Tidak ada efek samping klinis utama yang dilaporkan.';
                  final fdaDosage = localDrug?['fdaDosage'] ?? 'Dosis harus mengikuti instruksi dokter.';
                  final fdaWarnings = localDrug?['fdaWarnings'] ?? 'Gunakan obat sesuai petunjuk.';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama Obat & Icon
                          Row(
                            children: [
                              const Icon(Icons.medication, color: AppTheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Informasi Kandungan & Golongan
                          _buildInfoRow('Kandungan Aktif:', genericName, isBoldValue: true),
                          _buildInfoRow('Golongan / Tipe:', '$category / $type'),
                          
                          const Divider(height: 16),
                          
                          // Detail Medis Resmi FDA & Scraping
                          _buildMedicalSection('Kegunaan Utama / Indikasi:', fdaIndications, AppTheme.success),
                          const SizedBox(height: 8),
                          _buildMedicalSection('Aturan Dosis & Cara Kerja:', fdaDosage, AppTheme.primary),
                          const SizedBox(height: 8),
                          _buildMedicalSection('Efek Samping:', fdaSideEffects, AppTheme.danger),
                          const SizedBox(height: 8),
                          _buildMedicalSection('Informasi Penting Penggunaan:', fdaWarnings, AppTheme.warning),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Reset setelah hanya info
              setState(() {
                _selectedImage = null;
                _webImageBytes = null;
                _webImageName = null;
                _ocrText = '';
                _detectedDrugs = [];
              });
            },
            child: const Text('Selesai & Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalSection(String title, String content, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          content,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }


  Future<void> _submitPrescription() async {
    final hasImage = _selectedImage != null || _webImageBytes != null;
    if (!hasImage && (!_useCustomUrl || _customUrlController.text.trim().isEmpty)) {
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
      final token = ref.read(authProvider).token;
      final dioClient = ApiClient.createDio(token: token);

      if (_useCustomUrl && _customUrlController.text.trim().isNotEmpty) {
        // Link kustom
        await dioClient.post('/prescriptions', data: {
          'imageUrl': _customUrlController.text.trim(),
          'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        });
      } else {
        // Unggah file aslinya ke API backend via Multipart Form Data
        final dio.FormData formData = dio.FormData();
        
        if (_notesController.text.trim().isNotEmpty) {
          formData.fields.add(MapEntry('notes', _notesController.text.trim()));
        }

        if (kIsWeb && _webImageBytes != null) {
          formData.files.add(MapEntry(
            'file',
            dio.MultipartFile.fromBytes(
              _webImageBytes!,
              filename: _webImageName ?? 'prescription.jpg',
            ),
          ));
        } else if (_selectedImage != null) {
          formData.files.add(MapEntry(
            'file',
            await dio.MultipartFile.fromFile(
              _selectedImage!.path,
              filename: 'prescription.jpg',
            ),
          ));
        }

        await dioClient.post('/prescriptions/upload', data: formData);
      }

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
          _webImageBytes = null;
          _webImageName = null;
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
                    child: (_selectedImage != null || _webImageBytes != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                                : Image.file(_selectedImage!, fit: BoxFit.cover),
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
                        if (!_useCustomUrl) {
                          _selectedImage = null;
                          _webImageBytes = null;
                          _webImageName = null;
                        }
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
              // Submit & OCR Flow
              if (_isOcrProcessing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Membaca resep dengan OCR...', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Mengidentifikasi kandungan obat...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                )
              else if (isUploading)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Sedang mengunggah resep ke Apoteker...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              else if ((_selectedImage != null || _webImageBytes != null) && _ocrText.isEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppTheme.primary,
                  ),
                  onPressed: _processImageOcr,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Scan & Proses Resep Dokter (OCR)'),
                )
              else if (_ocrText.isNotEmpty) ...[
                // Hasil OCR teks
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teks Terbaca:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ocrText,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Hasil deteksi obat
                if (_detectedDrugs.isNotEmpty) ...[
                  Text(
                    'Obat Terdeteksi (${_detectedDrugs.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ..._detectedDrugs.map((drug) => _PrescriptionDrugResultCard(
                        drug: drug,
                        currency: currency,
                        token: ref.read(authProvider).token,
                      )),
                  const SizedBox(height: 16),
                ],

                // Panel Pilihan Tindakan Anda
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PILIHAN TINDAKAN ANDA:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 12),
                      
                      // Opsi 1: Tebus & Beli
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _submitPrescription,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Tebus & Beli Obat Ini'),
                      ),
                      const SizedBox(height: 8),
                      
                      // Opsi 2: Sekedar Ingin Tahu
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showJustInfoDialog,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Saya Hanya Ingin Tahu Info Obat'),
                      ),
                      const SizedBox(height: 8),

                      // Opsi 3: Batal / Scan Ulang
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _webImageBytes = null;
                            _webImageName = null;
                            _ocrText = '';
                            _detectedDrugs = [];
                          });
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Batal & Scan Ulang'),
                      ),
                    ],
                  ),
                ),
              ] else
                ElevatedButton(
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
                      if (status == 'VERIFIED' && item['prescribedDrugs'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rekomendasi Obat:',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              ...(item['prescribedDrugs'] as List).map((drug) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '• ${drug['name']} (x${drug['quantity']})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                      if (status == 'VERIFIED') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              (item['orders'] as List? ?? []).isNotEmpty ? 'Telah Ditebus' : 'Siap Ditebus',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (item['orders'] as List? ?? []).isNotEmpty ? Colors.grey : AppTheme.success,
                              ),
                            ),
                            if ((item['orders'] as List? ?? []).isEmpty)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  widget.onRedeemPrescription?.call(item);
                                },
                                child: const Text('Beli Obat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
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

class _PrescriptionDrugResultCard extends StatefulWidget {
  final Map<String, dynamic> drug;
  final NumberFormat currency;
  final String? token;

  const _PrescriptionDrugResultCard({
    required this.drug,
    required this.currency,
    this.token,
  });

  @override
  State<_PrescriptionDrugResultCard> createState() => _PrescriptionDrugResultCardState();
}

class _PrescriptionDrugResultCardState extends State<_PrescriptionDrugResultCard> {
  Map<String, dynamic>? _fdaInfo;

  @override
  void initState() {
    super.initState();
    // Only load FDA info if local drugs is empty to avoid unnecessary token issues
    final localDrugsVal = widget.drug['localDrugs'];
    final List localDrugs = localDrugsVal is List ? localDrugsVal : [];
    if (localDrugs.isEmpty) {
      _loadFdaInfo();
    }
  }

  Future<void> _loadFdaInfo() async {
    try {
      final name = widget.drug['detectedName'] ?? '';
      final response =
          await ApiClient.createDio(token: widget.token).get('/external/fda/label?name=$name');
      if (response.data is Map) {
        setState(() => _fdaInfo = Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      // FDA info tidak tersedia
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final localDrugsVal = widget.drug['localDrugs'];
      final List localDrugs = localDrugsVal is List ? localDrugsVal : [];
      final rxnormVal = widget.drug['rxnorm'];
      final Map rxnorm = rxnormVal is Map ? rxnormVal : {};

      // Safely parse the local drug map to prevent dynamic cast errors
      Map? localDrug;
      if (localDrugs.isNotEmpty && localDrugs.first is Map) {
        localDrug = localDrugs.first as Map;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.medication, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.drug['detectedName']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (rxnorm['name'] != null)
                          Text(
                            rxnorm['name'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Detail Kandungan & Info Medis Lokal (Langsung Tampil di bawah nama)
            if (localDrug != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kandungan Aktif
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kandungan Aktif: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                        ),
                        Expanded(
                          child: Text(
                            localDrug['genericName']?.toString() ?? localDrug['activeIngredient']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Kegunaan Utama
                    if (localDrug['fdaIndications'] != null || localDrug['description'] != null) ...[
                      const Text(
                        'Kegunaan Utama / Indikasi:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.success),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (localDrug['fdaIndications'] ?? localDrug['description']).toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Aturan Dosis / Cara Kerja
                    if (localDrug['fdaDosage'] != null) ...[
                      const Text(
                        'Aturan Dosis & Cara Kerja:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localDrug['fdaDosage'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Efek Samping
                    if (localDrug['fdaSideEffects'] != null) ...[
                      const Text(
                        'Efek Samping:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.danger),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localDrug['fdaSideEffects'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Informasi Penting Penggunaan
                    if (localDrug['fdaWarnings'] != null) ...[
                      const Text(
                        'Informasi Penting Penggunaan:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.warning),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localDrug['fdaWarnings'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Info FDA (Jika tidak ada info lokal, tampilkan info FDA sebagai cadangan)
            if (localDrug == null && _fdaInfo != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kandungan Aktif (FDA)
                    if (_fdaInfo!['activeIngredient'] != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kandungan Aktif (FDA): ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                          ),
                          Expanded(
                            child: Text(
                              _fdaInfo!['activeIngredient'].toString(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Indikasi / Kegunaan (FDA)
                    if (_fdaInfo!['indications'] != null || _fdaInfo!['purpose'] != null) ...[
                      const Text(
                        'Kegunaan Utama / Indikasi (FDA):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.success),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_fdaInfo!['indications'] ?? _fdaInfo!['purpose']).toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Dosis (FDA)
                    if (_fdaInfo!['dosage'] != null) ...[
                      const Text(
                        'Aturan Dosis & Cara Kerja (FDA):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fdaInfo!['dosage'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Efek Samping (FDA)
                    if (_fdaInfo!['sideEffects'] != null) ...[
                      const Text(
                        'Efek Samping (FDA):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.danger),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fdaInfo!['sideEffects'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Peringatan (FDA)
                    if (_fdaInfo!['warnings'] != null || _fdaInfo!['contraindications'] != null) ...[
                      const Text(
                        'Peringatan & Kontraindikasi (FDA):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.warning),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_fdaInfo!['warnings'] ?? _fdaInfo!['contraindications']).toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Tersedia di apotek ini
            if (localDrugs.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Tersedia di Apotek Ini:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...localDrugs.take(3).map((d) {
                      if (d is! Map) return const SizedBox.shrink();
                      final Map dMap = d;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dMap['name']?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _PrescriptionTypeBadge(type: dMap['type']?.toString() ?? 'GENERIK'),
                                      const SizedBox(width: 4),
                                      _PrescriptionCategoryBadge(category: dMap['category']?.toString() ?? 'BEBAS'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.currency.format(dMap['sellPrice'] is num ? dMap['sellPrice'] : (double.tryParse(dMap['sellPrice']?.toString() ?? '') ?? 0.0)),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Obat tidak tersedia di apotek ini',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building _PrescriptionDrugResultCard: $e\n$stackTrace');
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          'Gagal memuat detail obat "${widget.drug['detectedName'] ?? '-'}": $e',
          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
        ),
      );
    }
  }
}

class _PrescriptionTypeBadge extends StatelessWidget {
  final String type;
  const _PrescriptionTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type == 'GENERIK'
            ? AppTheme.success.withOpacity(0.1)
            : AppTheme.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          color: type == 'GENERIK' ? AppTheme.success : AppTheme.primaryLight,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PrescriptionCategoryBadge extends StatelessWidget {
  final String category;
  const _PrescriptionCategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case 'KERAS':
        color = AppTheme.danger;
        break;
      case 'BEBAS_TERBATAS':
        color = AppTheme.warning;
        break;
      default:
        color = AppTheme.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

