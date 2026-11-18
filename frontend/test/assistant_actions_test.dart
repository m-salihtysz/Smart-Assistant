import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/services/assistant_actions.dart';
import 'package:smart_assistant/services/user_store.dart';

void main() {
  late List<String> scheduled;
  late AssistantActions actions;
  var nextId = 1;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser('test@example.com');
    scheduled = [];
    nextId = 1;
    actions = AssistantActions(
      nextNotificationId: () => nextId++,
      scheduleActivity: (id, title, when) async =>
          scheduled.add('a:$id:$title:$when'),
      scheduleRoutine: (id, title, wd, h, m) async =>
          scheduled.add('r:$id:$title:$wd:$h:$m'),
    );
  });

  test(
    'add_activity: tam sayı yerine ondalık/metin saat de kabul edilir',
    () async {
      final err = await actions.apply({
        'type': 'add_activity',
        'payload': {
          'date': '2026-03-06',
          'title': 'Dişçi',
          'hour': 14.0,
          'minute': '30',
          'reminder': 'true',
        },
      });
      expect(err, isNull);
      final saved = (await UserStore.readList('activities')).single as Map;
      expect(saved['hour'], 14);
      expect(saved['minute'], 30);
      expect(saved['reminder'], true);
      expect(saved['notificationId'], 1);
      expect(scheduled.single, startsWith('a:1:Dişçi:2026-03-06 14:30'));
    },
  );

  test(
    'add_activity: geçersiz tarih/saat/başlık reddedilir, kayıt oluşmaz',
    () async {
      for (final payload in [
        {'date': '2026-02-31', 'title': 'x'},
        {'date': 'yarın', 'title': 'x'},
        {'date': '2026-03-06', 'title': ' '},
        {'date': '2026-03-06', 'title': 'x', 'hour': 25},
      ]) {
        expect(
          await actions.apply({'type': 'add_activity', 'payload': payload}),
          isNotNull,
          reason: '$payload',
        );
      }
      expect(await UserStore.readList('activities'), isEmpty);
    },
  );

  test(
    'add_routine: hafta günü ve hatırlatıcı (Pazartesi=1) zamanlanır',
    () async {
      final err = await actions.apply({
        'type': 'add_routine',
        'payload': {
          'weekday': 0,
          'title': 'Yürüyüş',
          'hour': 7,
          'minute': 0,
          'reminder': true,
        },
      });
      expect(err, isNull);
      expect(scheduled.single, 'r:1:Yürüyüş:1:7:0');
      final data = await UserStore.readMap('routines');
      expect((data['0'] as List).length, 1);
      expect(data.containsKey('completions'), isTrue);

      expect(
        await actions.apply({
          'type': 'add_routine',
          'payload': {'weekday': 9, 'title': 'x'},
        }),
        isNotNull,
      );
    },
  );

  test(
    'add_finance_transaction: tutar metin olabilir, sıfır/negatif reddedilir',
    () async {
      expect(
        await actions.apply({
          'type': 'add_finance_transaction',
          'payload': {
            'kind': 'income',
            'amount': '1500,50',
            'title': 'Maaş',
            'date': '2026-03-06',
          },
        }),
        isNull,
      );
      final saved =
          (await UserStore.readList('finance_transactions')).single as Map;
      expect(saved['type'], 'gelir');
      expect(saved['category'], 'Diğer');
      expect(saved['amount'], 1500.5);

      for (final amount in [0, -5, 'abc']) {
        expect(
          await actions.apply({
            'type': 'add_finance_transaction',
            'payload': {
              'kind': 'expense',
              'amount': amount,
              'title': 'x',
              'date': '2026-03-06',
            },
          }),
          isNotNull,
        );
      }
      expect((await UserStore.readList('finance_transactions')).length, 1);
    },
  );

  test('normalizeTxType eski ve yeni değerleri tek biçime çevirir', () {
    expect(normalizeTxType('income'), 'gelir');
    expect(normalizeTxType('gelir'), 'gelir');
    expect(normalizeTxType('expense'), 'gider');
    expect(normalizeTxType('gider'), 'gider');
    expect(normalizeTxType(null), 'gider');
  });

  test('add_note ve set_sport_plan_for_day', () async {
    expect(
      await actions.apply({
        'type': 'add_note',
        'payload': {'title': 'Plan', 'body': 'Spor'},
      }),
      isNull,
    );
    expect(
      await actions.apply({
        'type': 'add_note',
        'payload': {'title': '', 'body': ''},
      }),
      isNotNull,
    );

    expect(
      await actions.apply({
        'type': 'set_sport_plan_for_day',
        'payload': {
          'weekday': 5,
          'region': 'Tüm vücut',
          'exercises': [
            {'name': 'Şınav', 'reps': 12, 'sets': '3'},
            {'name': ''},
            'bozuk',
          ],
        },
      }),
      isNull,
    );
    final plan = (await UserStore.readMap('sport_plans'))['5'] as Map;
    expect(plan['region'], 'Tüm vücut');
    expect((plan['exercises'] as List).single['sets'], 3);
  });

  test('bilinmeyen action ve bozuk biçim reddedilir', () async {
    expect(
      await actions.apply({'type': 'drop_tables', 'payload': {}}),
      contains('Bilinmeyen'),
    );
    expect(
      await actions.apply({'type': 'add_note', 'payload': 'metin'}),
      isNotNull,
    );
    expect(await actions.apply({'payload': {}}), isNotNull);
  });

  test('veri aktif kullanıcıya yazılır', () async {
    await actions.apply({
      'type': 'add_note',
      'payload': {'title': 'a', 'body': ''},
    });
    UserStore.setUser('baska@example.com');
    expect(await UserStore.readList('notes_v2'), isEmpty);
  });
}
