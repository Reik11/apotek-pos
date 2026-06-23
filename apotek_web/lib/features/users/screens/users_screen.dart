import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_layout.dart';
import '../providers/users_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _roles = ['ADMIN', 'APOTEKER', 'KASIR', 'PASIEN'];
  static const _shifts = ['PAGI', 'SIANG', 'MALAM', 'OFF'];
  static const _roleColors = {
    'SUPER_ADMIN': Color(0xFF7C3AED),
    'ADMIN': Color(0xFF2563EB),
    'APOTEKER': AppTheme.primary,
    'KASIR': Color(0xFFD97706),
    'PASIEN': AppTheme.success,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final filtered = usersState.users.where((u) {
      final q = _searchQuery.toLowerCase();
      return (u['name'] ?? '').toLowerCase().contains(q) ||
          (u['email'] ?? '').toLowerCase().contains(q) ||
          (u['role'] ?? '').toLowerCase().contains(q);
    }).toList();

    return MainLayout(
      currentRoute: '/users',
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manajemen Pengguna',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kelola staf, apoteker, dan akun kasir apotek',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Tambah Staf'),
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari nama, email, atau role...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Table
          Expanded(
            child: usersState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Tidak ada pengguna ditemukan', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.5),
                                1: FlexColumnWidth(2.5),
                                2: FlexColumnWidth(1.5),
                                3: FlexColumnWidth(1.2),
                                4: FlexColumnWidth(1.5),
                                5: FlexColumnWidth(1.8),
                                6: FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.primary),
                                  children: ['Nama', 'Email', 'Role', 'Shift', 'Status', 'Terdaftar', 'Aksi']
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(h,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                ),
                                ...filtered.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final user = entry.value;
                                  final role = user['role'] as String? ?? '';
                                  final roleColor = _roleColors[role] ?? AppTheme.primary;
                                  final isActive = user['isActive'] as bool? ?? true;
                                  final createdAt = user['createdAt'] != null
                                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user['createdAt']))
                                      : '-';

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                    ),
                                    children: [
                                      // Nama
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: roleColor.withValues(alpha: 0.15),
                                              child: Text(
                                                (user['name'] as String? ?? 'U')[0].toUpperCase(),
                                                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                user['name'] ?? '-',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Email
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(user['email'] ?? '-',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Role
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: roleColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            role,
                                            style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // Shift
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            user['shift'] ?? 'OFF',
                                            style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // Status
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                color: isActive ? AppTheme.success : Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isActive ? 'Aktif' : 'Nonaktif',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: isActive ? AppTheme.success : Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Tanggal daftar
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(createdAt,
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ),
                                      // Aksi
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: role == 'SUPER_ADMIN'
                                            ? const Icon(Icons.shield_rounded, color: Colors.grey, size: 18)
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined,
                                                        color: AppTheme.primary, size: 18),
                                                    tooltip: 'Edit Pengguna',
                                                    onPressed: () => _showEditUserDialog(context, user),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded,
                                                        color: AppTheme.danger, size: 18),
                                                    tooltip: 'Hapus Pengguna',
                                                    onPressed: () => _confirmDelete(context, user),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Apakah Anda yakin ingin menghapus akun "${user['name']}"?\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(usersProvider.notifier).deleteUser(user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Pengguna berhasil dihapus' : 'Gagal menghapus pengguna'),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ));
      }
    }
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'KASIR';
    String selectedShift = 'OFF';
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Tambah Pengguna Baru'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nama Lengkap')),
                  const SizedBox(height: 12),
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'email@apotek.com')),
                  const SizedBox(height: 12),
                  const Text('No. Telepon (opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '08xx-xxxx-xxxx')),
                  const SizedBox(height: 12),
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Min. 6 karakter',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setS(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Role / Jabatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setS(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 12),
                  const Text('Shift Kerja', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedShift,
                    decoration: const InputDecoration(),
                    items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setS(() => selectedShift = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                final ok = await ref.read(usersProvider.notifier).createUser({
                  'name': nameCtrl.text,
                  'email': emailCtrl.text,
                  'password': passCtrl.text,
                  'role': selectedRole,
                  'shift': selectedShift,
                  'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                });
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Pengguna berhasil ditambahkan!'),
                    backgroundColor: AppTheme.success,
                  ));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']);
    final emailCtrl = TextEditingController(text: user['email']);
    final phoneCtrl = TextEditingController(text: user['phone']);
    String selectedRole = user['role'] ?? 'KASIR';
    String selectedShift = user['shift'] ?? 'OFF';
    bool isActive = user['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit Pengguna'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nama Lengkap')),
                  const SizedBox(height: 12),
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'email@apotek.com')),
                  const SizedBox(height: 12),
                  const Text('No. Telepon (opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '08xx-xxxx-xxxx')),
                  const SizedBox(height: 12),
                  const Text('Role / Jabatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setS(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 12),
                  const Text('Shift Kerja', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedShift,
                    items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setS(() => selectedShift = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (v) => setS(() => isActive = v!),
                      ),
                      const Text('Akun Aktif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                final ok = await ref.read(usersProvider.notifier).updateUser(user['id'], {
                  'name': nameCtrl.text,
                  'email': emailCtrl.text,
                  'role': selectedRole,
                  'shift': selectedShift,
                  'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                  'isActive': isActive,
                });
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Pengguna berhasil diperbarui!'),
                    backgroundColor: AppTheme.success,
                  ));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
