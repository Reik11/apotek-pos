import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _savingProfile = false;
  bool _savingPass = false;
  bool _requestingOtp = false;
  bool _otpPassSent = false;
  final _otpPassCtrl = TextEditingController();
  String? _profileMsg;
  String? _passMsg;
  bool _profileOk = false;
  bool _passOk = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = ref.read(authProvider).user;
    _nameCtrl.text = user?.name ?? '';
    _emailCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() { _savingProfile = true; _profileMsg = null; });
    try {
      final dio = ApiClient.createDio();
      final res = await dio.put('/users/profile', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() { _profileOk = true; _profileMsg = 'Profil berhasil diperbarui!'; });
        ref.read(authProvider.notifier).refreshUser(res.data);
      }
    } on DioException catch (e) {
      setState(() { _profileOk = false; _profileMsg = e.response?.data['message'] ?? 'Gagal memperbarui profil'; });
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _requestChangePasswordOtp() async {
    setState(() => _requestingOtp = true);
    try {
      final success = await ref.read(authProvider.notifier).requestChangePasswordOtp();
      if (success && mounted) {
        setState(() { _otpPassSent = true; _requestingOtp = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode OTP dikirim ke email Anda! Berlaku 5 menit.'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        setState(() => _requestingOtp = false);
      }
    } catch (_) {
      setState(() => _requestingOtp = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() { _passOk = false; _passMsg = 'Konfirmasi password tidak cocok'; });
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() { _passOk = false; _passMsg = 'Password minimal 6 karakter'; });
      return;
    }
    if (!_otpPassSent || _otpPassCtrl.text.isEmpty) {
      setState(() { _passOk = false; _passMsg = 'Minta dan masukkan kode OTP terlebih dahulu'; });
      return;
    }
    setState(() { _savingPass = true; _passMsg = null; });
    try {
      final dio = ApiClient.createDio();
      await dio.put('/users/change-password', data: {
        'currentPassword': _currentPassCtrl.text,
        'newPassword': _newPassCtrl.text,
        'otp': _otpPassCtrl.text.trim(),
      });
      setState(() {
        _passOk = true;
        _passMsg = 'Password berhasil diubah!';
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _otpPassCtrl.clear();
        _otpPassSent = false;
      });
    } on DioException catch (e) {
      setState(() { _passOk = false; _passMsg = e.response?.data['message'] ?? 'Gagal mengganti password'; });
    } finally {
      setState(() => _savingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return MainLayout(
      currentRoute: '/profile',
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://api.dicebear.com/9.x/adventurer/png?seed=${Uri.encodeComponent(user?.name ?? 'Admin')}&backgroundColor=b6e3f4',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              (user?.name ?? 'A').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '-',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user?.role ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowCard,
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.person_outline), text: 'Edit Profil'),
                        Tab(icon: Icon(Icons.lock_outline), text: 'Ganti Password'),
                      ],
                    ),
                    SizedBox(
                      height: 560,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEditProfile(),
                          _buildChangePassword(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Perbarui nama dan email akun Anda', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          _label('Nama Lengkap'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined), hintText: 'Nama lengkap'),
          ),
          const SizedBox(height: 14),
          _label('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'email@apotek.com'),
          ),
          if (_profileMsg != null) ...[
            const SizedBox(height: 12),
            _statusBanner(_profileMsg!, _profileOk),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _savingProfile ? null : _saveProfile,
              icon: _savingProfile
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_savingProfile ? 'Menyimpan...' : 'Simpan Perubahan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Keamanan Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Ubah password untuk menjaga keamanan akun Anda', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          _label('Password Saat Ini'),
          const SizedBox(height: 6),
          TextField(
            controller: _currentPassCtrl,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Password lama',
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _label('Password Baru'),
          const SizedBox(height: 6),
          TextField(
            controller: _newPassCtrl,
            obscureText: _obscureNew,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_reset),
              hintText: 'Minimal 8 karakter',
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildPassStrengthBar(_newPassCtrl.text),
          const SizedBox(height: 10),
          _label('Konfirmasi Password Baru'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.check_circle_outline),
              hintText: 'Ulangi password baru',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          // OTP Section
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Kode OTP Verifikasi *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpPassCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.security_outlined),
                        hintText: _otpPassSent ? '6-digit kode dari email' : 'Minta kode OTP dahulu',
                        counterText: '',
                        enabled: _otpPassSent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const SizedBox(height: 19),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _otpPassSent ? AppTheme.success : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _requestingOtp ? null : _requestChangePasswordOtp,
                      icon: _requestingOtp
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_otpPassSent ? Icons.check_circle_outline : Icons.send_rounded, size: 16),
                      label: Text(
                        _otpPassSent ? 'Terkirim' : 'Kirim OTP',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_passMsg != null) ...[
            const SizedBox(height: 10),
            _statusBanner(_passMsg!, _passOk),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _savingPass ? null : _changePassword,
              icon: _savingPass
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.key_rounded),
              label: Text(_savingPass ? 'Menyimpan...' : 'Ganti Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassStrengthBar(String pass) {
    int strength = 0;
    if (pass.length >= 6) strength++;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9]'))) strength++;
    if (pass.contains(RegExp(r'[!@#\$%^&*]'))) strength++;

    final labels = ['', 'Sangat Lemah', 'Lemah', 'Cukup', 'Kuat', 'Sangat Kuat'];
    final colors = [
      Colors.grey.shade300,
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.lightGreen,
      AppTheme.success,
    ];

    if (pass.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < strength ? colors[strength] : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          labels[strength.clamp(0, 5)],
          style: TextStyle(
            fontSize: 11,
            color: colors[strength.clamp(0, 5)],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
  );

  Widget _statusBanner(String message, bool isOk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isOk ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isOk ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(isOk ? Icons.check_circle_outline : Icons.error_outline,
            color: isOk ? AppTheme.success : AppTheme.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(color: isOk ? AppTheme.success : AppTheme.danger, fontSize: 13)),
        ),
      ],
    ),
  );
}
