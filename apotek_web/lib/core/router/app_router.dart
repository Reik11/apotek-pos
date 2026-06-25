import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web screens
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/kasir/screens/kasir_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/reports/screens/user_reports_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/suppliers/screens/suppliers_screen.dart';
import '../../features/purchase_orders/screens/purchase_orders_screen.dart';
import '../../features/outlets/screens/outlets_screen.dart';

// Profile
import '../../features/auth/screens/profile_screen.dart';

// Mobile screens
import '../../features/mobile/apoteker/screens/apoteker_home_screen.dart';
import '../../features/mobile/pasien/screens/pasien_home_screen.dart';

// Layout
import '../../shared/widgets/main_layout.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ===== WEB ROUTES (SHELL) =====
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const DashboardScreen()),
          ),
          GoRoute(
            path: '/kasir',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const KasirScreen()),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const InventoryScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const ReportsScreen()),
          ),
          GoRoute(
            path: '/admin-reports',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const UserReportsScreen()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const UsersScreen()),
          ),
          GoRoute(
            path: '/suppliers',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const SuppliersScreen()),
          ),
          GoRoute(
            path: '/purchase-orders',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const PurchaseOrdersScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: '/outlets',
            pageBuilder: (context, state) => _fadeTransitionPage(state, const OutletsScreen()),
          ),
        ],
      ),

      // ===== MOBILE ROUTES =====
      GoRoute(
        path: '/apoteker',
        builder: (context, state) => const ApotekerHomeScreen(),
      ),
      GoRoute(
        path: '/pasien',
        builder: (context, state) => const PasienHomeScreen(),
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}