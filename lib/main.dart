import 'dart:io';

import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/admin_home_page.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'services/supabase_service.dart';

void main() async {
  HttpOverrides.global = _AllowSelfSignedCert();
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FATAL: ${details.exception}\n${details.stack}');
  };

  try {
    await SupabaseService.initialize();
  } catch (e, s) {
    debugPrint('Supabase init failed: $e\n$s');
  }

  runApp(const MyApp());
}

class _AllowSelfSignedCert extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.modeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Grocery App',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const NoGlowScrollBehavior(),
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final _api = ApiService();
  Widget? _startPage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _api.getToken();
    if (token != null) {
      final user = await _api.getSavedUser();
      final role = user['role'] as String? ?? 'user';
      if (mounted) {
        setState(() {
          _startPage = role == 'admin' ? const AdminHomePage() : const HomePage();
        });
      }
    } else {
      if (mounted) {
        setState(() => _startPage = const HomePage());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startPage == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _startPage!;
  }
}
