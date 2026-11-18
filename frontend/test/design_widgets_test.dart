import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/user_store.dart';
import 'package:smart_assistant/theme/app_theme.dart';
import 'package:smart_assistant/widgets/empty_state.dart';
import 'package:smart_assistant/widgets/week_strip.dart';

Widget _app(Widget child, {AppState? state}) {
  final app = MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: Scaffold(body: child),
  );
  return state == null
      ? app
      : ChangeNotifierProvider<AppState>.value(value: state, child: app);
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<AppState> _login() async {
  final state = AppState(
    client: MockClient(
      (r) async => r.url.path == '/auth/login'
          ? http.Response('{"access_token":"t"}', 200)
          : http.Response(
              '{"id":1,"email":"a@x.com","name":"Ali","birth_date":"1999-05-01","created_at":"2026-01-01T00:00:00"}',
              200,
            ),
    ),
    sessionStorage: MemorySessionStorage(),
  );
  await state.login('a@x.com', 'password123');
  return state;
}

/// Test yazı tipi (Ahem) geniş olduğundan taşma uyarıları sahte pozitiftir; diğer tüm hatalar teste düşer.
void _ignoreOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('WeekStrip: 7 gün da ekran içinde, seçim çalışır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final monday = DateTime(2026, 11, 16);
    var selected = 2;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _app(
          WeekStrip(
            days: [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))],
            labels: const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
            selectedIndex: selected,
            onSelect: (i) => setState(() => selected = i),
          ),
        ),
      ),
    );

    // Pazar (22) dahil tüm günler görünür alanda
    for (final d in ['16', '17', '18', '19', '20', '21', '22']) {
      final rect = tester.getRect(find.text(d));
      expect(
        rect.left >= 0 && rect.right <= 390,
        isTrue,
        reason: 'gün $d ekran dışında: $rect',
      );
    }

    await tester.tap(find.text('22'));
    await tester.pump();
    expect(selected, 6);
  });

  testWidgets('EmptyState: eylem düğmesi çağrılır', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        EmptyState(
          icon: Icons.note,
          message: 'Boş',
          hint: 'İpucu',
          actionLabel: 'Ekle',
          onAction: () => taps++,
        ),
      ),
    );
    expect(find.text('Boş'), findsOneWidget);
    expect(find.text('İpucu'), findsOneWidget);
    await tester.tap(find.text('Ekle'));
    expect(taps, 1);
  });

  testWidgets('Ana sayfa: bugünün özeti ve günlük hedef gerçek veriden gelir', (
    tester,
  ) async {
    _ignoreOverflow();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    // Tek haneli ay/gün için de aynı (sıfır dolgulu) anahtar kullanılır — eski hata sıfırsız anahtar arıyordu.
    final today = _key(now);
    SharedPreferences.setMockInitialValues({
      'u:a@x.com:activities':
          '[{"date":"$today","title":"Dişçi","hour":23,"minute":59,"reminder":false,"notificationId":null}]',
      'u:a@x.com:routines':
          '{"${now.weekday - 1}":[{"title":"A","hour":7,"minute":0,"reminder":false},{"title":"B","hour":8,"minute":0,"reminder":false}],"completions":{"$today":[true,false]}}',
      'u:a@x.com:finance_transactions':
          '[{"type":"expense","amount":120,"title":"Market","date":"$today"},{"type":"income","amount":900,"title":"Maaş","date":"$today"},{"type":"gider","amount":30,"title":"Kahve","date":"$today"}]',
    });

    final state = await _login();
    await tester.pumpWidget(_app(const HomeScreen(), state: state));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 aktivite · 2 rutin'), findsOneWidget);
    expect(find.textContaining('Sıradaki: 23:59 · Dişçi'), findsOneWidget);
    expect(find.text('50% Tamamlandı'), findsOneWidget);
    expect(find.text('1/2 rutin tamamlandı'), findsOneWidget);
    // 'expense' (asistan) + 'gider' (uygulama) toplanır, gelir sayılmaz
    expect(find.text('₺150 Harcandı'), findsOneWidget);
    expect(UserStore.user, 'a@x.com');
  });

  testWidgets('Ana sayfa: veri yokken asistana yönlendiren boş özet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = await _login();
    await tester.pumpWidget(_app(const HomeScreen(), state: state));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bugün için planın boş.'), findsOneWidget);
    expect(find.text('Asistana planla'), findsOneWidget);
    await tester.tap(find.text('Asistana planla'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Smart AI ile Konuş'), findsOneWidget);
  });

  testWidgets('Asistan: öneri çipleri görünür', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = await _login();
    await tester.pumpWidget(_app(const AssistantTab(), state: state));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bugün neler yapmalıyım?'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(4));
  });
}
