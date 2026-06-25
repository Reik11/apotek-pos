import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseAnimation;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _controller.forward();

    // Jalankan pengecekan status inisialisasi auth
    _startAuthCheck();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAuthCheck() {
    // Tunggu minimal 1.2 detik agar animasi splash sempat berputar indah
    Timer(const Duration(milliseconds: 1200), () {
      _checkAndRedirect();
    });
  }

  void _checkAndRedirect() {
    if (!mounted || _hasRedirected) return;

    final authState = ref.read(authProvider);

    if (authState.isInitialized) {
      _hasRedirected = true;
      final user = authState.user;

      if (user != null) {
        final role = user.role;
        if (role == 'PASIEN') {
          context.go('/pasien');
        } else if (role == 'APOTEKER') {
          context.go('/apoteker');
        } else {
          context.go('/dashboard');
        }
      } else {
        context.go('/login');
      }
    } else {
      // Jika belum selesai inisialisasi, tunggu lagi sedikit
      Timer(const Duration(milliseconds: 150), () {
        _checkAndRedirect();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Stack(
          children: [
            // Lingkaran dekoratif latar belakang (sama dengan login screen untuk keselarasan tema)
            Positioned(
              top: -100,
              right: -100,
              child: _buildDecorCircle(300, Colors.white.withOpacity(0.03)),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: _buildDecorCircle(250, Colors.white.withOpacity(0.04)),
            ),
            
            // Konten Tengah
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Kombinasikan skala kemunculan dengan denyut pulsing
                  final scale = _controller.value < 0.6 
                      ? _logoScale.value 
                      : _logoScale.value * (1.0 + (_pulseAnimation.value - 1.0) * 0.3);

                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Icon ApotekPOS
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_pharmacy_rounded,
                          color: AppTheme.primary,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Judul Aplikasi
                    Text(
                      'ApotekPOS',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Subtitle
                    Text(
                      'Sistem Manajemen Apotek & Kasir',
                      style: GoogleFonts.inter(
                        color: AppTheme.sidebarHint.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Indikator Loading Halus di Bawah
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Memeriksa Sesi...',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
