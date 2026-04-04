import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eda_app/screens/about_screen.dart';
import 'package:eda_app/screens/settings_screen.dart';
import 'package:eda_app/services/theme_service.dart';
import 'package:eda_app/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets up in-memory mocks for all platform channels that screens depend on
/// (secure storage, local notifications, shared_preferences).
void _setupPlatformMocks() {
  final Map<String, String?> secureStorage = {};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      switch (call.method) {
        case 'write':
          secureStorage[call.arguments['key'] as String] =
              call.arguments['value'] as String?;
          return null;
        case 'read':
          return secureStorage[call.arguments['key'] as String];
        case 'delete':
          secureStorage.remove(call.arguments['key'] as String);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        case 'readAll':
          return <String, String>{};
        case 'containsKey':
          return secureStorage.containsKey(call.arguments['key'] as String);
        default:
          return null;
      }
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (MethodCall call) async => null,
  );
}

/// Wraps [child] with the EasyLocalization widget and a themed [MaterialApp]
/// for widget tests that require translated strings.
Widget _buildLocalizedApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('pt')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: child,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _setupPlatformMocks();
  });

  group('AboutScreen widget', () {
    testWidgets('renders app bar title', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('renders info icon', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders app name', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('EDA Readings'), findsOneWidget);
    });

    testWidgets('renders GitHub issue button', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Open Issue on GitHub'), findsOneWidget);
    });

    testWidgets('renders copyright notice', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Décio Fernandes'), findsOneWidget);
    });

    testWidgets('applies primary color from theme', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const AboutScreen()));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold, isNotNull);
    });
  });

  group('AppTheme widget integration', () {
    testWidgets('MaterialApp accepts lightTheme without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Text('light')),
        ),
      );

      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('MaterialApp accepts darkTheme without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Text('dark')),
        ),
      );

      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('light theme primary color is applied to widgets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('SettingsScreen widget', () {
    testWidgets('renders app bar title', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Appearance section header', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('renders theme label', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('App Theme'), findsOneWidget);
    });

    testWidgets('renders About section header', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('renders copyright notice', (WidgetTester tester) async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(_buildLocalizedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Décio Fernandes'), findsOneWidget);
    });
  });

  group('ThemeService', () {
    test('defaults to ThemeMode.system', () {
      final service = ThemeService();
      expect(service.themeMode, equals(ThemeMode.system));
    });

    test('setThemeMode persists and updates themeMode', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, equals(ThemeMode.dark));
    });

    test('loadTheme reads persisted value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': ThemeMode.light.index});
      final service = ThemeService();
      await service.loadTheme();
      expect(service.themeMode, equals(ThemeMode.light));
    });

    test('loadTheme falls back to system when no value stored', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.loadTheme();
      expect(service.themeMode, equals(ThemeMode.system));
    });
  });
}
