import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/about_screen.dart';
import 'screens/import_export_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await NotificationService().initialize();
  await ThemeService().loadTheme();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EDA Readings',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.themeMode,
      home: const DashboardScreen(),
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/reading': (context) => const ReadingScreen(),
        '/about': (context) => const AboutScreen(),
        '/import_export': (context) => const ImportExportScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
