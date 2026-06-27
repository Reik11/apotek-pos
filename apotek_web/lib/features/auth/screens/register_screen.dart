import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  String _passwordValue = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua field harus diisi!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return false;
    }

    final email = _emailController.text.trim();
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format email tidak valid! (Harus memiliki simbol @ dan domain, misal: nama@domain.com)'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return false;
    }

    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password tidak cocok!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return false;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal 6 karakter!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return false;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus menyetujui syarat & ketentuan!'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleRequestOtp() async {
    if (!_validateForm()) return;

    setState(() => _isSendingOtp = true);
    try {
      final success = await ref
          .read(authProvider.notifier)
          .requestRegisterOtp(_emailController.text.trim());

      if (success && mounted) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode OTP telah dikirim! Periksa email Anda.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;
    
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode OTP dari email Anda!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          otp: _otpController.text.trim(),
        );

    if (success && mounted) {
      context.go('/pasien');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: isMobile ? _buildMobileLayout(authState) : _buildWebLayout(authState),
    );
  }

  // ===== WEB LAYOUT (Split Screen) =====
  Widget _buildWebLayout(AuthState authState) {
    return Row(
      children: [
        // KIRI — Branding Panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D5C3A), Color(0xFF1B8C5E), Color(0xFF26C47E)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80, right: -80,
                  child: _decorCircle(240, Colors.white.withOpacity(0.05)),
                ),
                Positioned(
                  bottom: -60, left: -60,
                  child: _decorCircle(200, Colors.white.withOpacity(0.07)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Bergabung dengan\nApotekPOS',
                          style: TextStyle(
                            color: Colors.white, fontSize: 34,
                            fontWeight: FontWeight.w700, height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Buat akun pasien dan nikmati kemudahan\npemesanan obat secara online.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 16, height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildBenefit('🛒', 'Pesan obat bebas kapan saja'),
                        _buildBenefit('📋', 'Upload resep dokter secara digital'),
                        _buildBenefit('🚚', 'Pilih antar ke rumah atau ambil sendiri'),
                        _buildBenefit('📦', 'Lacak status pesanan secara real-time'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // KANAN — Form Register
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: _buildRegisterForm(authState),
            ),
          ),
        ),
      ],
    );
  }

  // ===== MOBILE LAYOUT =====
  Widget _buildMobileLayout(AuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Buat Akun Baru',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Daftar sebagai pasien ApotekPOS',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildRegisterForm(authState),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ===== FORM REGISTER =====
  Widget _buildRegisterForm(AuthState authState) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daftar Akun Pasien',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Isi formulir di bawah untuk membuat akun',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // Nama Lengkap
          _buildLabel('Nama Lengkap'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Nama lengkap Anda',
              prefixIcon: Icon(Icons.badge_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // Email
          _buildLabel('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'contoh@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // Password
          _buildLabel('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (v) => setState(() => _passwordValue = v),
            decoration: InputDecoration(
              hintText: 'Minimal 6 karakter',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_passwordValue.isNotEmpty) _buildPasswordStrength(_passwordValue),

          // Konfirmasi Password
          _buildLabel('Konfirmasi Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            onSubmitted: (_) => _handleRegister(),
            decoration: InputDecoration(
              hintText: 'Ulangi password Anda',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Syarat & Ketentuan
          Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                  activeColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saya menyetujui syarat & ketentuan penggunaan layanan ApotekPOS',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // OTP Section (Selalu terlihat, dengan tombol Kirim OTP di samping kanannya)
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Kode OTP Email *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: '6-digit kode',
                        prefixIcon: Icon(Icons.security_outlined, size: 18),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _otpSent ? AppTheme.success : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: (authState.isLoading || _isSendingOtp) ? null : _handleRequestOtp,
                  icon: _isSendingOtp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_otpSent ? Icons.check_circle_outline : Icons.send_rounded, size: 16),
                  label: Text(_isSendingOtp
                      ? 'Mengirim...'
                      : (_otpSent ? 'Kirim Ulang' : 'Kirim OTP')),
                ),
              ),
            ],
          ),
          if (_otpSent) ...[
            const SizedBox(height: 8),
            Text(
              'Kode OTP telah dikirim ke ${_emailController.text.trim()}. Berlaku 5 menit.',
              style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
            ),
          ],

          const SizedBox(height: 24),

          // Tombol Daftar Akun
          if (authState.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                onPressed: _handleRegister,
                label: const Text('Daftar Akun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

          // Error
          if (authState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(authState.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Link ke Login
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Sudah punya akun? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Masuk di sini',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
    );
  }

  Widget _buildBenefit(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildPasswordStrength(String pass) {
    int strength = 0;
    if (pass.length >= 6) strength++;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9]'))) strength++;
    if (pass.contains(RegExp(r'[!@#$%^&*]'))) strength++;

    final labels = ['', 'Sangat Lemah', 'Lemah', 'Cukup', 'Kuat', 'Sangat Kuat'];
    final colors = [Colors.grey, Colors.red, Colors.orange, Colors.yellow.shade700, Colors.lightGreen, AppTheme.success];
    final idx = strength.clamp(0, 5);

    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(5, (i) => Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: i < strength ? colors[idx] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
        ),
        const SizedBox(width: 8),
        Text(labels[idx], style: TextStyle(fontSize: 11, color: colors[idx], fontWeight: FontWeight.w600)),
      ],
    ));
  }
}
