import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/theme/app_theme.dart';

Future<AppState> _loggedIn({bool complete = true}) async {
  final me = complete
      ? '{"id":1,"email":"a@x.com","name":"Ali","birth_date":"1999-05-01","created_at":"2026-01-01T00:00:00"}'
      : '{"id":1,"email":"a@x.com","name":null,"birth_date":null,"created_at":"2026-01-01T00:00:00"}';
  final state = AppState(
    client: MockClient(
      (r) async => r.url.path == '/auth/login'
          ? http.Response('{"access_token":"t"}', 200)
          : http.Response(me, 200),
    ),
    sessionStorage: MemorySessionStorage(),
  );
  await state.login('a@x.com', 'password123');
  return state;
}

/// Çizim sırasında oluşan hatalar. Test yazı tipi (Ahem) geniş olduğundan taşma uyarıları,
/// ağsız ortamdaki görsel hataları ve yalnızca debug'daki ListTile mürekkep uyarısı sayılmaz.
final List<String> _errors = [];

void _record(FlutterErrorDetails d) {
  final text = d.exceptionAsString();
  const ignored = [
    'overflowed',
    'NetworkImageLoadException',
    'HTTP request failed',
    'ListTile background color',
  ];
  if (ignored.any(text.contains)) return;
  _errors.add(text.split('\n').first);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _errors.clear();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    FlutterError.onError = _record;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = await _loggedIn();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          themeMode: mode,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_errors, isEmpty);
  }

  final screens = <String, Widget Function()>{
    'WelcomeScreen': () => const WelcomeScreen(),
    'RegisterScreen': () => const RegisterScreen(),
    'OnboardingScreen': () => const OnboardingScreen(),
    'HomeScreen': () => const HomeScreen(),
    'SportTab': () => const SportTab(),
    'FinanceTab': () => const FinanceTab(),
    'RoutinesTab': () => const RoutinesTab(),
    'ActivitiesTab': () => const ActivitiesTab(),
    'NotesTab': () => const NotesTab(),
    'AssistantTab': () => const AssistantTab(),
    'SettingsScreen': () => const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} hatasız çizilir', (tester) async {
      await pumpScreen(tester, entry.value());
    });
  }

  for (final entry in screens.entries) {
    testWidgets('${entry.key} koyu temada hatasız çizilir', (tester) async {
      await pumpScreen(tester, entry.value(), mode: ThemeMode.dark);
    });
  }

  testWidgets('HomeScreen alt menü sekmeleri hatasız gezilir', (tester) async {
    await pumpScreen(tester, const HomeScreen());
    for (final icon in [
      Icons.settings_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.home_outlined,
    ]) {
      await tester.tap(find.byIcon(icon).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_errors, isEmpty, reason: '$icon');
    }
  });
}
