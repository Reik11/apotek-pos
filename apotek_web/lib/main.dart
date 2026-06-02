import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // tambah async
  WidgetsFlutterBinding.ensureInitialized(); // tambah ini
  await initializeDateFormatting('id_ID', null); // tambah ini
  runApp(
    const ProviderScope(
      child: ApotekApp(),
    ),
  );
}

class ApotekApp extends ConsumerWidget {
  const ApotekApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ApotekPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
