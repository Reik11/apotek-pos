import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ===== SIDEBAR =====
          _buildSidebar(context, ref, user),

          // ===== MAIN CONTENT =====
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      width: 240,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.sidebarGradient,
      ),
      child: Column(
        children: [
          // Logo Section
          _buildLogoSection(),

          const SizedBox(height: 8),

          // Divider tipis
          Divider(
              color: AppTheme.sidebarText.withOpacity(0.15),
              thickness: 1,
              indent: 20,
              endIndent: 20),

          const SizedBox(height: 8),

          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _buildNavItems(context, user),
              ),
            ),
          ),

          // Divider
          Divider(
              color: AppTheme.sidebarText.withOpacity(0.15),
              thickness: 1,
              indent: 20,
              endIndent: 20),

          // User Section + Logout
          _buildUserSection(context, ref, user),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ApotekPOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Sistem Manajemen',
                style: TextStyle(
                  color: AppTheme.sidebarHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context, dynamic user) {
    final navItems = [
      _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          route: '/dashboard'),
      _NavItem(
          icon: Icons.point_of_sale_rounded, label: 'Kasir', route: '/kasir'),
      _NavItem(
          icon: Icons.inventory_2_rounded,
          label: 'Inventaris',
          route: '/inventory'),
      _NavItem(
          icon: Icons.bar_chart_rounded, label: 'Laporan', route: '/reports'),
      _NavItem(
          icon: Icons.message_rounded,
          label: 'Pengaduan',
          route: '/admin-reports',
          roles: ['SUPER_ADMIN', 'ADMIN', 'APOTEKER']),
      _NavItem(
          icon: Icons.local_shipping_rounded,
          label: 'Supplier',
          route: '/suppliers',
          roles: ['SUPER_ADMIN', 'ADMIN', 'APOTEKER']),
      _NavItem(
          icon: Icons.receipt_long_rounded,
          label: 'Purchase Order',
          route: '/purchase-orders',
          roles: ['SUPER_ADMIN', 'ADMIN', 'APOTEKER']),
      _NavItem(
          icon: Icons.people_rounded,
          label: 'Pengguna',
          route: '/users',
          roles: ['SUPER_ADMIN', 'ADMIN']),
      _NavItem(
          icon: Icons.storefront_rounded,
          label: 'Outlet',
          route: '/outlets',
          roles: ['SUPER_ADMIN']),
    ];

    final userRole = user?.role as String?;
    final filteredItems = navItems.where((item) {
      if (item.roles == null) return true;
      if (userRole == null) return false;
      return item.roles!.contains(userRole);
    }).toList();

    return filteredItems
        .map((item) => _NavItemWidget(
              item: item,
              isActive: currentRoute.startsWith(item.route),
              onTap: () => context.go(item.route),
            ))
        .toList();
  }

  Widget _buildUserSection(BuildContext context, WidgetRef ref, dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Profil user (klik untuk ke halaman profil)
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.accent.withOpacity(0.25),
                    child: Text(
                      (user?.name?.isNotEmpty == true)
                          ? user!.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Pengguna',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.role ?? '',
                          style: TextStyle(
                              color: AppTheme.sidebarHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: AppTheme.sidebarHint, size: 16),
                ],
              ),
            ),
          ),

          // Tombol Logout
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded,
                      color: AppTheme.danger.withOpacity(0.8), size: 16),
                  const SizedBox(width: 10),
                  Text(
                    'Keluar',
                    style: TextStyle(
                        color: AppTheme.danger.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Helper classes
// ============================================================
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final List<String>? roles;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.route,
      this.roles});
}

class _NavItemWidget extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItemWidget(
      {required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.sidebarActive.withOpacity(0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: isActive
                ? Border(left: BorderSide(color: AppTheme.accent, width: 3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: isActive ? Colors.white : AppTheme.sidebarHint,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.sidebarHint,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
