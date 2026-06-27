import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '83173429765-c9cc3qhq3vrjo93o5ormpefrk224fnls.apps.googleusercontent.com',
    serverClientId: '83173429765-c9cc3qhq3vrjo93o5ormpefrk224fnls.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    try {
      // Di web, signIn() kadang tidak mengembalikan idToken langsung.
      // Kita signOut dulu untuk memastikan fresh login, lalu signIn.
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      String? idToken = googleAuth.idToken;

      // Jika idToken null, coba signInSilently untuk refresh credential
      if (idToken == null) {
        final silentUser = await _googleSignIn.signInSilently();
        if (silentUser != null) {
          googleAuth = await silentUser.authentication;
          idToken = googleAuth.idToken;
        }
      }

      if (idToken == null) {
        throw Exception('Gagal mendapatkan ID Token dari Google.');
      }

      final success = await ref.read(authProvider.notifier).loginWithGoogle(idToken);
      if (success && mounted) {
        context.go('/');
      } else if (mounted) {
        final error = ref.read(authProvider).error ?? 'Gagal masuk menggunakan Google.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error Google Sign-In: $e\n\nTips: Google Client ID harus dikonfigurasi di web/index.html untuk rilis web.'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password harus diisi!')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (success && mounted) {
      final user = ref.read(authProvider).user;
      final role = user?.role ?? '';

      if (role == 'PASIEN') {
        context.go('/pasien');
      } else if (role == 'APOTEKER') {
        context.go('/apoteker');
      } else {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body:
          isMobile ? _buildMobileLayout(authState) : _buildWebLayout(authState),
    );
  }

  // ===== WEB LAYOUT =====
  Widget _buildWebLayout(AuthState authState) {
    return Row(
      children: [
        // KIRI — Branding Panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Stack(
              children: [
                // Dekorasi lingkaran
                Positioned(
                  top: -80,
                  right: -80,
                  child: _decorCircle(240, Colors.white.withOpacity(0.05)),
                ),
                Positioned(
                  bottom: -60,
                  left: -60,
                  child: _decorCircle(200, Colors.white.withOpacity(0.07)),
                ),
                Positioned(
                  top: 100,
                  left: -40,
                  child: _decorCircle(120, Colors.white.withOpacity(0.04)),
                ),
                // Konten branding
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'ApotekPOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sistem Manajemen Apotek\nTerintegrasi & Modern',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        ..._buildFeatureBullets(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // KANAN — Form Login
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: _buildLoginForm(authState),
            ),
          ),
        ),
      ],
    );
  }

  // ===== MOBILE LAYOUT =====
  Widget _buildMobileLayout(AuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.local_pharmacy_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ApotekPOS',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sistem Manajemen Apotek Terintegrasi',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
          _buildLoginForm(authState),
          const SizedBox(height: 24),
          // Info role khusus mobile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Info Login:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Apoteker & Pasien → App Mobile',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  '• Admin & Kasir → Gunakan Web Browser',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== FORM LOGIN =====
  Widget _buildLoginForm(AuthState authState) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
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
            'Selamat Datang 👋',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Masukkan akun Anda untuk melanjutkan',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),

          // Email Field
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'contoh@apotek.com',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.go('/forgot-password'),
              child: const Text(
                'Lupa Password?',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tombol Login
          if (authState.isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleLogin,
                child: const Text(
                  'Masuk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('atau', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _handleGoogleLogin,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 28),
                label: const Text(
                  'Masuk dengan Google',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Error
          if (authState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.error!,
                      style:
                          const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Link ke Register
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Belum punya akun? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.go('/register'),
                  child: const Text(
                    'Daftar di sini',
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

  // ===== HELPER WIDGETS =====
  List<Widget> _buildFeatureBullets() {
    final features = [
      '💊 Manajemen inventaris dengan FIFO',
      '🧾 Kasir POS dengan struk digital',
      '📱 Pemesanan online pasien',
      '🔬 OCR resep dokter otomatis',
    ];
    return features
        .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  f,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
