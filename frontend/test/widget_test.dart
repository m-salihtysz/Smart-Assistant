import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';

AppState _state() => AppState(
  client: MockClient((_) async => http.Response('{}', 401)),
  sessionStorage: MemorySessionStorage(),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Giriş yapılmamışken karşılama ekranı gösterilir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(appState: _state()));
    await tester.pump();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Oturum geri yüklenirken yükleme göstergesi çıkar', (
    WidgetTester tester,
  ) async {
    final state = _state()..isRestoring = true;
    await tester.pumpWidget(MyApp(appState: state));

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
