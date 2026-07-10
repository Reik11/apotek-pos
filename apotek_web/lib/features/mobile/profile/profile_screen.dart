import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'profile_provider.dart';
import '../pasien/screens/address_screen.dart';
import '../pasien/screens/report_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool isFromBottomNav;
  const ProfileScreen({super.key, this.isFromBottomNav = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _otpPassController = TextEditingController();

  bool _obscureCurrent = true;

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _activeSubPage; // null (menu), 'edit_profile', 'change_password', 'medical_profile'

  // Controller Data Medis
  final _birthDateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicDiseasesController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  String? _selectedGender;
  bool _isPregnant = false;
  bool _isBreastfeeding = false;
  DateTime? _selectedBirthDate;


  @override
  void initState() {
    super.initState();
    // Isi data dari auth state
    final user = ref.read(authProvider).user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _otpPassController.dispose();

    
    _birthDateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    _chronicDiseasesController.dispose();
    _currentMedicationsController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalProfile() async {
    final data = await ref.read(profileProvider.notifier).getMedicalProfile();
    if (data != null && mounted) {
      setState(() {
        if (data['birthDate'] != null) {
          _selectedBirthDate = DateTime.tryParse(data['birthDate']);
          if (_selectedBirthDate != null) {
            _birthDateController.text = "${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}";
          }
        }
        _selectedGender = data['gender'];
        _weightController.text = data['weight']?.toString() ?? '';
        _heightController.text = data['height']?.toString() ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _chronicDiseasesController.text = data['chronicDiseases'] ?? '';
        _currentMedicationsController.text = data['currentMedications'] ?? '';
        _isPregnant = data['isPregnant'] as bool? ?? false;
        _isBreastfeeding = data['isBreastfeeding'] as bool? ?? false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.isFromBottomNav ? null : AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== HEADER PROFIL =====
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: widget.isFromBottomNav ? 8 : 32,
                bottom: 32,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Avatar DiceBear
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://api.dicebear.com/9.x/adventurer/png?seed=${Uri.encodeComponent(user?.name ?? 'User')}&backgroundColor=b6e3f4,c0aede,d1d4f9',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '-',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badge role
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Text(
                      _getRoleLabel(user?.role ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ===== MENU PILIHAN / FORM AKTIF =====
            if (_activeSubPage == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Edit Profil',
                      subtitle: 'Ubah nama dan email Anda',
                      onTap: () => setState(() => _activeSubPage = 'edit_profile'),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.lock_outline,
                      title: 'Ganti Password',
                      subtitle: 'Perbarui kata sandi akun Anda',
                      onTap: () => setState(() => _activeSubPage = 'change_password'),
                    ),
                    if (user?.role == 'PASIEN') ...[
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: Icons.medical_services_outlined,
                        title: 'Informasi Medis',
                        subtitle: 'Atur tanggal lahir, alergi, dan riwayat kesehatan',
                        onTap: () {
                          setState(() => _activeSubPage = 'medical_profile');
                          _loadMedicalProfile();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: Icons.location_on_outlined,
                        title: 'Alamat Pengiriman',
                        subtitle: 'Kelola alamat tujuan pengantaran obat',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddressScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Laporan Pengaduan',
                        subtitle: 'Kirimkan keluhan layanan atau masalah pesanan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportScreen()),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Section Info Akun
                    _SectionCard(
                      title: 'Informasi Akun',
                      icon: Icons.info_outline,
                      child: Column(
                        children: [
                          _InfoRow(
                              label: 'Role',
                              value: _getRoleLabel(user?.role ?? '')),
                          const Divider(),
                          _InfoRow(label: 'ID Pengguna', value: user?.id ?? '-'),
                          const Divider(),
                          _InfoRow(
                            label: 'Status',
                            value: 'Aktif',
                            valueColor: AppTheme.success,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tombol Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Konfirmasi Logout'),
                              content:
                                  const Text('Apakah kamu yakin ingin keluar?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.danger,
                                  ),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            await ref.read(authProvider.notifier).logout();
                            if (mounted) context.go('/login');
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                        label: const Text('Keluar dari Akun', style: TextStyle(color: AppTheme.danger)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ] else if (_activeSubPage == 'edit_profile') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
                          onPressed: () => setState(() => _activeSubPage = null),
                        ),
                        const Text(
                          'Kembali ke Menu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'Edit Profil',
                      icon: Icons.person_outline,
                      child: Column(
                        children: [
                          if (profileState.successMessage != null)
                            _MessageBanner(
                              message: profileState.successMessage!,
                              isSuccess: true,
                            ),
                          if (profileState.error != null)
                            _MessageBanner(
                              message: profileState.error!,
                              isSuccess: false,
                            ),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _nameController,
                            label: 'Nama Lengkap',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 16),
                          _InputField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: profileState.isSaving
                                  ? null
                                  : () async {
                                      final success = await ref
                                          .read(profileProvider.notifier)
                                          .updateProfile(
                                            name: _nameController.text.trim(),
                                            email: _emailController.text.trim(),
                                          );
                                      if (success && mounted) {
                                        final currentUser = ref.read(authProvider).user;
                                        if (currentUser != null) {
                                          ref.read(authProvider.notifier).refreshUser({
                                            'id': currentUser.id,
                                            'name': _nameController.text.trim(),
                                            'email': _emailController.text.trim(),
                                            'role': currentUser.role,
                                            'outletId': currentUser.outletId,
                                            'avatarUrl': currentUser.avatarUrl,
                                          });
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Profil berhasil diperbarui!'),
                                            backgroundColor: AppTheme.success,
                                          ),
                                        );
                                      }
                                    },
                              icon: profileState.isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Simpan Perubahan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ] else if (_activeSubPage == 'change_password') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
                          onPressed: () => setState(() => _activeSubPage = null),
                        ),
                        const Text(
                          'Kembali ke Menu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'Ganti Password',
                      icon: Icons.lock_outline,
                      child: Column(
                        children: [
                          _InputField(
                            controller: _currentPassController,
                            label: 'Password Saat Ini',
                            icon: Icons.lock_outlined,
                            obscureText: _obscureCurrent,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InputField(
                            controller: _newPassController,
                            label: 'Password Baru',
                            icon: Icons.lock_reset_outlined,
                            obscureText: _obscureNew,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InputField(
                            controller: _confirmPassController,
                            label: 'Konfirmasi Password Baru',
                            icon: Icons.check_circle_outline,
                            obscureText: _obscureConfirm,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                           const SizedBox(height: 16),
                           Row(
                             children: [
                               Expanded(
                                 child: _InputField(
                                   controller: _otpPassController,
                                   label: 'Masukkan Kode OTP',
                                   icon: Icons.key_outlined,
                                   keyboardType: TextInputType.number,
                                 ),
                               ),
                               const SizedBox(width: 8),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: AppTheme.primary,
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                 ),
                                 onPressed: () async {
                                   final ok = await ref.read(profileProvider.notifier).requestChangePasswordOtp();
                                   if (ok && mounted) {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       const SnackBar(
                                         content: Text('Kode OTP berhasil dikirim ke email Anda!'),
                                         backgroundColor: AppTheme.success,
                                       ),
                                     );
                                   }
                                 },
                                 child: const Text('Minta OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                               ),
                             ],
                           ),
                           const SizedBox(height: 16),
                           Container(
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: AppTheme.primary.withOpacity(0.05),
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: const Row(
                               children: [
                                 Icon(Icons.info_outline,
                                     size: 14, color: AppTheme.primary),
                                 SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     'Untuk keamanan, Anda wajib meminta & memasukkan OTP sebelum ganti password',
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: AppTheme.primary,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 20),
                           SizedBox(
                             width: double.infinity,
                             child: ElevatedButton.icon(
                               onPressed: profileState.isSaving
                                   ? null
                                   : () async {
                                       if (_currentPassController.text.isEmpty ||
                                           _newPassController.text.isEmpty ||
                                           _confirmPassController.text.isEmpty) {
                                         ScaffoldMessenger.of(context)
                                             .showSnackBar(
                                           const SnackBar(
                                             content:
                                                 Text('Semua field harus diisi!'),
                                             backgroundColor: AppTheme.danger,
                                           ),
                                         );
                                         return;
                                       }
                                       if (_newPassController.text !=
                                           _confirmPassController.text) {
                                         ScaffoldMessenger.of(context)
                                             .showSnackBar(
                                           const SnackBar(
                                             content: Text(
                                                 'Password baru tidak cocok!'),
                                             backgroundColor: AppTheme.danger,
                                           ),
                                         );
                                         return;
                                       }
                                       if (_newPassController.text.length < 6) {
                                         ScaffoldMessenger.of(context)
                                             .showSnackBar(
                                           const SnackBar(
                                             content: Text(
                                                 'Password minimal 6 karakter!'),
                                             backgroundColor: AppTheme.danger,
                                           ),
                                         );
                                         return;
                                       }
                                       if (_otpPassController.text.isEmpty) {
                                         ScaffoldMessenger.of(context)
                                             .showSnackBar(
                                           const SnackBar(
                                             content: Text(
                                                 'Masukkan kode OTP ganti password!'),
                                             backgroundColor: AppTheme.danger,
                                           ),
                                         );
                                         return;
                                       }
                                       final success = await ref
                                           .read(profileProvider.notifier)
                                           .changePassword(
                                             currentPassword:
                                                 _currentPassController.text,
                                             newPassword: _newPassController.text,
                                             otp: _otpPassController.text.trim(),
                                           );
                                       if (success && mounted) {
                                         _currentPassController.clear();
                                         _newPassController.clear();
                                         _confirmPassController.clear();
                                         _otpPassController.clear();
                                         ScaffoldMessenger.of(context)
                                             .showSnackBar(
                                           const SnackBar(
                                             content:
                                                 Text('Password berhasil diubah!'),
                                             backgroundColor: AppTheme.success,
                                           ),
                                         );
                                       }
                                     },
                               icon: profileState.isSaving
                                   ? const SizedBox(
                                       width: 16,
                                       height: 16,
                                       child: CircularProgressIndicator(
                                         strokeWidth: 2,
                                         color: Colors.white,
                                       ),
                                     )
                                   : const Icon(Icons.lock_reset),
                               label: const Text('Ubah Password'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppTheme.primaryLight,
                               ),
                             ),
                           ),

                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ] else if (_activeSubPage == 'medical_profile') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
                          onPressed: () => setState(() => _activeSubPage = null),
                        ),
                        const Text(
                          'Kembali ke Menu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'Informasi Medis',
                      icon: Icons.medical_services_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profileState.successMessage != null)
                            _MessageBanner(
                              message: profileState.successMessage!,
                              isSuccess: true,
                            ),
                          if (profileState.error != null)
                            _MessageBanner(
                              message: profileState.error!,
                              isSuccess: false,
                            ),
                          
                          // Tanggal Lahir (DatePicker)
                          const Text('Tanggal Lahir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedBirthDate ?? DateTime(2000),
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedBirthDate = picked;
                                  _birthDateController.text = "${picked.day}/${picked.month}/${picked.year}";
                                });
                              }
                            },
                            child: IgnorePointer(
                              child: _InputField(
                                controller: _birthDateController,
                                label: 'Pilih Tanggal Lahir',
                                icon: Icons.calendar_month_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Jenis Kelamin (Dropdown)
                          const Text('Jenis Kelamin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.wc_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                              DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedGender = val;
                              });
                            },
                            hint: const Text('Pilih Jenis Kelamin'),
                          ),
                          const SizedBox(height: 16),

                          // Berat & Tinggi Badan (Row)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Berat Badan (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _weightController,
                                      label: 'Contoh: 65',
                                      icon: Icons.monitor_weight_outlined,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tinggi Badan (cm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _heightController,
                                      label: 'Contoh: 170',
                                      icon: Icons.height_outlined,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Alergi Obat
                          const Text('Riwayat Alergi Obat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          _InputField(
                            controller: _allergiesController,
                            label: 'Contoh: Alergi penisilin (kosongkan jika tidak ada)',
                            icon: Icons.warning_amber_outlined,
                          ),
                          const SizedBox(height: 16),

                          // Penyakit Kronis
                          const Text('Penyakit Kronis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          _InputField(
                            controller: _chronicDiseasesController,
                            label: 'Contoh: Asma, Hipertensi (kosongkan jika tidak ada)',
                            icon: Icons.healing_outlined,
                          ),
                          const SizedBox(height: 16),

                          // Obat Rutin
                          const Text('Obat Rutin Saat Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          _InputField(
                            controller: _currentMedicationsController,
                            label: 'Contoh: Amlodipin (kosongkan jika tidak ada)',
                            icon: Icons.medication_outlined,
                          ),
                          const SizedBox(height: 20),

                          // Kondisi Khusus (Khusus Perempuan)
                          if (_selectedGender == 'Perempuan') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: const Text('Sedang Hamil', style: TextStyle(fontSize: 14)),
                                    value: _isPregnant,
                                    activeColor: AppTheme.primary,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) => setState(() => _isPregnant = val),
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    title: const Text('Sedang Menyusui', style: TextStyle(fontSize: 14)),
                                    value: _isBreastfeeding,
                                    activeColor: AppTheme.primary,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) => setState(() => _isBreastfeeding = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Tombol Simpan
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: profileState.isSaving
                                  ? null
                                  : () async {
                                      final success = await ref
                                          .read(profileProvider.notifier)
                                          .updateMedicalProfile(
                                            birthDate: _selectedBirthDate?.toIso8601String(),
                                            gender: _selectedGender,
                                            weight: double.tryParse(_weightController.text),
                                            height: double.tryParse(_heightController.text),
                                            allergies: _allergiesController.text.trim(),
                                            chronicDiseases: _chronicDiseasesController.text.trim(),
                                            currentMedications: _currentMedicationsController.text.trim(),
                                            isPregnant: _isPregnant,
                                            isBreastfeeding: _isBreastfeeding,
                                          );
                                      if (success && mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Informasi medis berhasil disimpan!'),
                                            backgroundColor: AppTheme.success,
                                          ),
                                        );
                                      }
                                    },
                              icon: profileState.isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Simpan Data Medis'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ]

          ],
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'APOTEKER':
        return '💊 Apoteker';
      case 'PASIEN':
        return '👤 Pasien';
      case 'ADMIN':
        return '🔧 Admin';
      case 'KASIR':
        return '💰 Kasir';
      default:
        return role;
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== WIDGET HELPERS =====

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _MessageBanner({
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppTheme.success : AppTheme.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
