import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web screens
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/kasir/screens/kasir_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/reports/screens/reports_screen.dart';

// Mobile screens
import '../../features/mobile/apoteker/screens/apoteker_home_screen.dart';
import '../../features/mobile/pasien/screens/pasien_home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ===== WEB ROUTES =====
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/kasir',
        builder: (context, state) => const KasirScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
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