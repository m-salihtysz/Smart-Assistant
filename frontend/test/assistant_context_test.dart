import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/services/assistant_context.dart';
import 'package:smart_assistant/services/format.dart';
import 'package:smart_assistant/services/user_store.dart';

void main() {
  // Çarşamba 18 Kasım 2026 (hafta Pzt 16 – Paz 22 Kasım)
  final now = DateTime(2026, 11, 18, 10, 30);

  Future<void> put(String key, Object value) =>
      UserStore.setString(key, jsonEncode(value), notify: false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser('a@example.com');
  });

  test('veri yokken boş ama geçerli bir bağlam üretir', () async {
    final ctx = await AssistantContext.build(now: now);
    expect(ctx['today_date'], '2026-11-18');
    expect(ctx['today_activities'], isEmpty);
    expect(ctx['activities'], isEmpty);
    expect(ctx['finance_summary'], isNull);
    expect(ctx['sport_plans_by_weekday'], isNull);
    expect(ctx['notes_summary'], isEmpty);
  });

  test(
    'aktiviteler: yalnızca yakın pencere, tarihe/saate göre sıralı, üst sınırlı',
    () async {
      await put('activities', [
        {'date': '2026-11-20', 'title': 'Gelecek', 'hour': 9, 'minute': 0},
        {'date': '2026-11-18', 'title': 'Bugün geç', 'hour': 15, 'minute': 0},
        {'date': '2026-11-18', 'title': 'Bugün erken', 'hour': 8, 'minute': 30},
        {'date': '2026-01-01', 'title': 'Çok eski', 'hour': 1, 'minute': 0},
        {'date': '2027-12-31', 'title': 'Çok uzak', 'hour': 1, 'minute': 0},
        {'date': '2026-11-12', 'title': 'Geçen hafta', 'hour': 1, 'minute': 0},
      ]);
      final ctx = await AssistantContext.build(now: now);
      final titles = (ctx['activities'] as List)
          .map((e) => e['title'])
          .toList();
      expect(titles, ['Geçen hafta', 'Bugün erken', 'Bugün geç', 'Gelecek']);
      expect((ctx['today_activities'] as List).map((e) => e['title']), [
        'Bugün erken',
        'Bugün geç',
      ]);
    },
  );

  test('aktivite sayısı sınırlıdır', () async {
    await put('activities', [
      for (var i = 0; i < 200; i++)
        {
          'date': dateKey(now.add(Duration(days: i % 30))),
          'title': 'a$i',
          'hour': 9,
          'minute': 0,
        },
    ]);
    final ctx = await AssistantContext.build(now: now);
    expect((ctx['activities'] as List).length, AssistantContext.maxActivities);
  });

  test('rutinler: bugünün rutinleri haftanın gününe göre seçilir', () async {
    await put('routines', {
      '2': [
        {'title': 'Çarşamba rutini', 'hour': 7, 'minute': 0, 'reminder': true},
      ],
      '4': [
        {'title': 'Cuma rutini', 'hour': 7, 'minute': 0},
      ],
      'completions': {
        '2026-11-18': [true],
      },
    });
    final ctx = await AssistantContext.build(now: now);
    expect((ctx['today_routines'] as List).single['title'], 'Çarşamba rutini');
    expect((ctx['routines_by_weekday'] as Map).keys.toSet(), {'2', '4'});
  });

  test(
    'finans: bugün/bu hafta/bu ay harcaması doğru hesaplanır, gelir harcamaya girmez',
    () async {
      await put('finance_transactions', [
        {
          'type': 'gider',
          'amount': 100,
          'title': 'Bugün',
          'date': '2026-11-18',
        },
        {
          'type': 'expense',
          'amount': 50,
          'title': 'AI ile (eski tip)',
          'date': '2026-11-17',
        },
        {
          'type': 'gider',
          'amount': 30,
          'title': 'Hafta başı',
          'date': '2026-11-16',
        },
        {
          'type': 'gider',
          'amount': 200,
          'title': 'Geçen hafta (aynı ay)',
          'date': '2026-11-05',
        },
        {
          'type': 'gider',
          'amount': 999,
          'title': 'Geçen ay',
          'date': '2026-10-30',
        },
        {
          'type': 'gelir',
          'amount': 5000,
          'title': 'Maaş',
          'date': '2026-11-01',
        },
        {
          'type': 'gider',
          'amount': 7,
          'title': 'Gelecek tarihli',
          'date': '2026-11-20',
        },
      ]);
      final fin =
          (await AssistantContext.build(now: now))['finance_summary'] as Map;
      expect(fin['spent_today'], 100);
      expect(
        fin['spent_this_week'],
        180,
        reason: '100 + 50 + 30 (gelecek tarihli sayılmaz)',
      );
      expect(fin['spent_this_month'], 100 + 50 + 30 + 200 + 7);
      expect(fin['total_income'], 5000);
      expect(fin['total_expense'], 100 + 50 + 30 + 200 + 999 + 7);
      expect(fin['transaction_count'], 7);
      final recent = fin['recent_transactions'] as List;
      expect(recent.first['date'], '2026-11-20', reason: 'en yeni önce');
      expect(
        recent.any((t) => t['title'] == 'Geçen ay'),
        isTrue,
        reason: '35 günlük pencere içinde',
      );
    },
  );

  test('finans: son işlem listesi sınırlıdır', () async {
    await put('finance_transactions', [
      for (var i = 0; i < 100; i++)
        {'type': 'gider', 'amount': 1, 'title': 't$i', 'date': dateKey(now)},
    ]);
    final fin =
        (await AssistantContext.build(now: now))['finance_summary'] as Map;
    expect(
      (fin['recent_transactions'] as List).length,
      AssistantContext.maxRecentTransactions,
    );
  });

  test(
    'notlar: en yeniler, sınırlı sayıda, önizleme kısaltılır, tam içerik gitmez',
    () async {
      final longBody = 'x' * 500;
      await put('notes_v2', [
        for (var i = 0; i < 50; i++) {'title': 'n$i', 'body': longBody},
      ]);
      final notes =
          (await AssistantContext.build(now: now))['notes_summary'] as List;
      expect(notes.length, AssistantContext.maxNotes);
      expect(notes.first['title'], 'n49');
      expect(
        (notes.first['preview'] as String).length,
        AssistantContext.notePreviewLength,
      );
      expect(notes.first['preview'], endsWith('...'));
    },
  );

  test('bozuk kayıtlar atlanır, bağlam yine üretilir', () async {
    await put('activities', [
      'metin',
      42,
      null,
      {'date': '2026-11-18', 'title': 'Sağlam', 'hour': '9', 'minute': 5.0},
      {'title': 'tarihsiz'},
    ]);
    await put('routines', {'2': 'liste değil', 'x': [], '9': []});
    await put('sport_plans', {
      '0': {
        'region': 'Göğüs',
        'exercises': [
          {'name': 'Şınav', 'reps': '12', 'sets': 3},
          'bozuk',
        ],
      },
      '1': 'bozuk',
    });
    await UserStore.setString(
      'finance_transactions',
      '{bozuk json',
      notify: false,
    );
    final ctx = await AssistantContext.build(now: now);
    final act = (ctx['activities'] as List).single as Map;
    expect(act['title'], 'Sağlam');
    expect(act['hour'], 9);
    expect(act['minute'], 5);
    final sport = ctx['sport_plans_by_weekday'] as Map;
    expect(sport.keys, ['0']);
    expect(((sport['0'] as Map)['exercises'] as List).single['reps'], 12);
    expect(ctx['finance_summary'], isNull);
  });

  test(
    'bağlam JSON olarak serileştirilebilir ve sunucu sınırının altındadır',
    () async {
      await put('notes_v2', [
        for (var i = 0; i < 200; i++) {'title': 'n$i', 'body': 'ş' * 400},
      ]);
      await put('activities', [
        for (var i = 0; i < 300; i++)
          {'date': dateKey(now), 'title': 'ö' * 80, 'hour': 9, 'minute': 0},
      ]);
      final ctx = await AssistantContext.build(now: now);
      final bytes = utf8.encode(jsonEncode(ctx)).length;
      expect(
        bytes,
        lessThan(60000),
        reason: 'backend max_context_bytes = 60000',
      );
    },
  );

  test('format yardımcıları', () {
    expect(dateKey(DateTime(2026, 3, 6)), '2026-03-06');
    final week = weekDaysOf(DateTime(2026, 11, 22)); // Pazar
    expect(week.first, DateTime(2026, 11, 16));
    expect(week.last, DateTime(2026, 11, 22));
    expect(weekDaysOf(DateTime(2026, 11, 16)).first, DateTime(2026, 11, 16));
  });
}
