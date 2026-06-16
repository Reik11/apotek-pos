import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'profile_provider.dart';

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

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

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
    super.dispose();
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
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
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

            // ===== EDIT PROFIL =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Section Edit Profil
                  _SectionCard(
                    title: 'Edit Profil',
                    icon: Icons.person_outline,
                    child: Column(
                      children: [
                        // Success/Error message
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

                        // Nama
                        _InputField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _InputField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Tombol simpan
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

                  const SizedBox(height: 16),

                  // Section Ganti Password
                  _SectionCard(
                    title: 'Ganti Password',
                    icon: Icons.lock_outline,
                    child: Column(
                      children: [
                        // Password lama
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

                        // Password baru
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

                        // Konfirmasi password
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
                        const SizedBox(height: 8),

                        // Password strength hint
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
                                  'Password minimal 6 karakter',
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

                        // Tombol ganti password
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: profileState.isSaving
                                ? null
                                : () async {
                                    // Validasi
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

                                    final success = await ref
                                        .read(profileProvider.notifier)
                                        .changePassword(
                                          currentPassword:
                                              _currentPassController.text,
                                          newPassword: _newPassController.text,
                                        );

                                    if (success && mounted) {
                                      _currentPassController.clear();
                                      _newPassController.clear();
                                      _confirmPassController.clear();
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

                  const SizedBox(height: 16),

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

                  const SizedBox(height: 16),

                  // Tombol Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Dialog konfirmasi logout
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
                      icon: const Icon(Icons.logout, color: AppTheme.danger),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: AppTheme.danger),
                      ),
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
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? AppTheme.textPrimary,
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
