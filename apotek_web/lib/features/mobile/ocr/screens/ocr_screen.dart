import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart' as dio;
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/providers/auth_provider.dart';



class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  File? _image;
  Uint8List? _webImageBytes;
  String? _webImageName;
  String _ocrText = '';
  bool _isProcessing = false;
  List<Map<String, dynamic>> _detectedDrugs = [];

  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Ambil gambar dari kamera atau galeri
  Future<void> _pickImage(ImageSource source) async {
    // Minta permission kamera
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin kamera diperlukan!')),
          );
        }
        return;
      }
    }

    final picker = ImagePicker();
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
        _image = File(pickedFile.path); // path placeholder
        _ocrText = '';
        _detectedDrugs = [];
      });
    } else {
      setState(() {
        _image = File(pickedFile.path);
        _webImageBytes = null;
        _webImageName = null;
        _ocrText = '';
        _detectedDrugs = [];
      });
    }

    await _processOcr();
  }

  // Proses OCR melalui Server Backend (Bisa di Web & HP)
  Future<void> _processOcr() async {
    final hasImage = _image != null || _webImageBytes != null;
    if (!hasImage) return;

    setState(() => _isProcessing = true);

    try {
      final dioClient = ApiClient.createDio();
      final dio.FormData formData = dio.FormData();

      if (kIsWeb && _webImageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          dio.MultipartFile.fromBytes(
            _webImageBytes!,
            filename: _webImageName ?? 'prescription.jpg',
          ),
        ));
      } else if (_image != null) {
        formData.files.add(MapEntry(
          'file',
          await dio.MultipartFile.fromFile(
            _image!.path,
            filename: 'prescription.jpg',
          ),
        ));
      }

      // Kirim gambar resep langsung ke backend untuk diproses OCR Donut
      final response = await dioClient.post(
        '/external/ocr-prescription',
        data: formData,
      );

      final String detectedText = response.data['rawText'] ?? '';
      
      setState(() {
        _ocrText = detectedText;
      });

      // Cari dan cocokkan obat-obatan lokal apotek dari teks hasil scan
      await _analyzeDrugs(detectedText);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses OCR: $e')),
        );
      }
    }
  }


  // Kirim hasil OCR ke backend
  Future<void> _analyzeDrugs(String text) async {
    try {
      final token = ref.read(authProvider).token;
      final response = await ApiClient.createDio(token: token).post(
        '/external/ocr-analyze',
        data: {'text': text},
      );

      setState(() {
        _detectedDrugs =
            List<Map<String, dynamic>>.from(response.data['drugs'] ?? []);
        _isProcessing = false;
      });
    } catch (e) {
      // Fallback: parse manual dari teks
      await _parseManually(text);
    }
  }

  bool _isUploadingPurchase = false;

  Future<void> _uploadPrescriptionForPurchase() async {
    final hasImage = _image != null || _webImageBytes != null;
    if (!hasImage) return;

    setState(() => _isUploadingPurchase = true);

    try {
      final token = ref.read(authProvider).token;
      final dioClient = ApiClient.createDio(token: token);
      final dio.FormData formData = dio.FormData();
      formData.fields.add(const MapEntry('notes', 'Diajukan otomatis dari hasil scan resep.'));

      if (kIsWeb && _webImageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          dio.MultipartFile.fromBytes(
            _webImageBytes!,
            filename: _webImageName ?? 'prescription.jpg',
          ),
        ));
      } else if (_image != null) {
        formData.files.add(MapEntry(
          'file',
          await dio.MultipartFile.fromFile(
            _image!.path,
            filename: 'prescription.jpg',
          ),
        ));
      }

      await dioClient.post('/prescriptions/upload', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resep berhasil diajukan untuk ditebus! Mengalihkan ke tab Resep...'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, 'BUY_PRESCRIPTION');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengajukan resep: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPurchase = false);
    }
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hasil scan ini hanya digunakan untuk pencarian informasi kandungan obat (tidak diajukan ke Apoteker).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ..._detectedDrugs.map((drug) {
                final name = drug['detectedName'] ?? '-';
                final rxnormName = drug['rxnorm']?['name'] ?? 'Kandungan umum';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $name ($rxnormName)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'JUST_INFO');
            },
            child: const Text('Selesai & Tutup'),
          ),
        ],
      ),
    );
  }


  // Parse manual jika backend tidak tersedia
  Future<void> _parseManually(String text) async {
    final lines = text.split('\n');
    final drugs = <Map<String, dynamic>>[];
    final token = ref.read(authProvider).token;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        // Cari info obat dari RxNorm berdasarkan setiap baris
        final response = await ApiClient.createDio(token: token).get(
            '/external/rxnorm/search?name=${Uri.encodeComponent(line.trim())}');

        final results = response.data as List? ?? [];
        if (results.isNotEmpty) {
          // Cari di database lokal apotek
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
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan Resep Dokter'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Area foto
            Container(
              width: double.infinity,
              height: 250,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_image != null || _webImageBytes != null)
                      ? AppTheme.primary
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: (kIsWeb && _webImageBytes != null)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_webImageBytes!, fit: BoxFit.cover),
                    )
                  : (_image != null && !kIsWeb)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Foto resep dokter di sini',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
            ),


            // Tombol ambil foto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galeri'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Loading
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Membaca resep...'),
                    Text(
                      'Mengidentifikasi obat dari RxNorm API',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Hasil OCR teks
            if (_ocrText.isNotEmpty && !_isProcessing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ocrText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Hasil deteksi obat
            if (_detectedDrugs.isNotEmpty && !_isProcessing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Obat Terdeteksi (${_detectedDrugs.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._detectedDrugs.map((drug) => _DrugResultCard(
                          drug: drug,
                          currency: currency,
                        )),
                    
                    const SizedBox(height: 24),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 12),
                          
                          // Opsi 1: Tebus & Beli
                          _isUploadingPurchase
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 44),
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _uploadPrescriptionForPurchase,
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

                          // Opsi 3: Beli Ulang Obat Sebelumnya
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              foregroundColor: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              Navigator.pop(context, 'BUY_PREVIOUS');
                            },
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Beli Ulang Obat dari Resep Sebelumnya'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],


            // Kosong setelah scan
            if (_image != null &&
                !_isProcessing &&
                _detectedDrugs.isEmpty &&
                _ocrText.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Tidak ada obat yang terdeteksi',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Coba foto dengan pencahayaan lebih baik',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Widget kartu hasil deteksi obat
class _DrugResultCard extends StatefulWidget {
  final Map<String, dynamic> drug;
  final NumberFormat currency;

  const _DrugResultCard({
    required this.drug,
    required this.currency,
  });

  @override
  State<_DrugResultCard> createState() => _DrugResultCardState();
}

class _DrugResultCardState extends State<_DrugResultCard> {
  bool _showDetails = false;
  Map<String, dynamic>? _fdaInfo;

  Future<void> _loadFdaInfo() async {
    try {
      final name = widget.drug['detectedName'] ?? '';
      final response =
          await ApiClient.createDio().get('/external/fda/label?name=$name');
      setState(() => _fdaInfo = response.data);
    } catch (e) {
      // FDA info tidak tersedia
    }
  }

  @override
  Widget build(BuildContext context) {
    final localDrugs = widget.drug['localDrugs'] as List? ?? [];
    final rxnorm = widget.drug['rxnorm'] as Map? ?? {};

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
                        widget.drug['detectedName'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (rxnorm['name'] != null)
                        Text(
                          rxnorm['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () {
                    setState(() => _showDetails = !_showDetails);
                    if (_showDetails && _fdaInfo == null) {
                      _loadFdaInfo();
                    }
                  },
                ),
              ],
            ),
          ),

          // Detail info
          if (_showDetails) ...[
            const Divider(height: 1),

            // Info FDA
            if (_fdaInfo != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_fdaInfo!['indications'] != null) ...[
                      const Text(
                        'Indikasi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        _fdaInfo!['indications'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_fdaInfo!['sideEffects'] != null) ...[
                      const Text(
                        'Efek Samping:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.danger,
                        ),
                      ),
                      Text(
                        _fdaInfo!['sideEffects'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

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
                    ...localDrugs.take(3).map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _TypeBadge(type: d['type']),
                                        const SizedBox(width: 4),
                                        _CategoryBadge(category: d['category']),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                widget.currency.format(d['sellPrice']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        )),
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
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

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

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

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
