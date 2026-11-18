import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';

void main() {
  testWidgets('onboarding ekranı hatasız çizilir (Spacer regresyonu)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      client: MockClient(
        (r) async => r.url.path == '/auth/login'
            ? http.Response('{"access_token":"t"}', 200)
            : http.Response(
                '{"id":1,"email":"a@x.com","name":null,"birth_date":null,"created_at":"2026-01-01T00:00:00"}',
                200,
              ),
      ),
      sessionStorage: MemorySessionStorage(),
    );
    await state.login('a@x.com', 'password123');
    await tester.pumpWidget(MyApp(appState: state));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Adın'), findsOneWidget);
  });
}
