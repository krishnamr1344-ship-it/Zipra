import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry/sentry.dart';
import 'pages/home_page.dart';
import 'pages/admin_home_page.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'services/app_info.dart';
import 'constants/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FATAL: ${details.exception}');
  };

  await Firebase.initializeApp();
  await AppInfo.load();

  final dsn = const String.fromEnvironment('SENTRY_DSN');
  if (dsn.isNotEmpty) {
    await Sentry.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 0.1;
      },
    );
  }
  runApp(const MyApp());
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
          title: 'Zipra',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const NoGlowScrollBehavior(),
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              foregroundColor: AppColors.onPrimary,
              backgroundColor: AppColors.primary,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              fillColor: AppColors.surface,
              filled: true,
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              selectedColor: AppColors.primary,
              labelStyle: const TextStyle(fontSize: 13),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: AppColors.surface,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
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

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  final _api = ApiService();
  Widget? _startPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTokenOnResume();
    }
  }

  Future<void> _checkTokenOnResume() async {
    final token = await _api.getToken();
    if (token != null && mounted) {
      try {
        await _api.getMe();
      } catch (_) {
        await _api.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _startup() async {
    final token = await _api.getToken();
    if (token != null) {
      final user = await _api.getSavedUser();
      final role = user['role'] as String? ?? 'user';
      final phone = user['phone'] as String? ?? '';
      if (mounted) {
        if (phone.isEmpty && role != 'admin') {
          setState(() => _startPage = const HomePage());
        } else {
          setState(() {
            _startPage = role == 'admin' ? const AdminHomePage() : const HomePage();
          });
        }
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
