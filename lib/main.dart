import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  await StorageService.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  Widget _initialRoute = const LoginScreen();
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isAuthenticated = await StorageService.isAuthenticated();

    if (mounted) {
      setState(() {
        _initialRoute = isAuthenticated
            ? const DashboardScreen()
            : const LoginScreen();
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A),
                  Color(0xFF3B82F6),
                  Color(0xFF60A5FA),
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return ErrorBoundary(
      child: AnimatedBuilder(
        animation: SettingsService.instance,
        builder: (context, child) {
          final isDark = SettingsService.instance.isDarkMode;
          final isEyeProtection = SettingsService.instance.isEyeProtectionMode;

          Widget app = MaterialApp(
            title: 'AMS Teacher',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: isDark
                  ? const Color(0xFF121212)
                  : const Color(0xFFF8FAFC),
              appBarTheme: AppBarTheme(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
            ),
            home: _initialRoute,
            debugShowCheckedModeBanner: false,
          );

          // Apply eye protection filter if enabled
          if (isEyeProtection) {
            app = ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x15FFA500), // Warm amber overlay with 8% opacity
                BlendMode.srcOver,
              ),
              child: app,
            );
          }

          return app;
        },
      ),
    );
  }
}
