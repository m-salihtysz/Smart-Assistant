import 'assistant_actions.dart';
import 'format.dart';
import 'user_store.dart';

/// Asistana (üçüncü taraf AI) gönderilecek bağlam özetini hazırlar.
///
/// Gizlilik ve maliyet için veri sınırlıdır: yalnızca yakın zamanlı aktiviteler,
/// kısa not önizlemeleri ve toplamlar gönderilir; bozuk kayıtlar atlanır.
class AssistantContext {
  AssistantContext._();

  /// Geçmişte/gelecekte kaç gün öncesi/sonrası aktiviteler gönderilsin.
  static const int activityDaysBack = 7;
  static const int activityDaysAhead = 90;
  static const int maxActivities = 60;
  static const int maxNotes = 20;
  static const int notePreviewLength = 120;
  static const int maxRecentTransactions = 30;
  static const int transactionDays = 35;

  static Future<Map<String, dynamic>> build({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = dateKey(today);

    final activities = await _activities(today, todayKey);
    final routines = await _routines(today);

    return {
      'today_date': todayKey,
      'today_activities': activities.today,
      'today_routines': routines.today,
      // Yakın zamanlı aktiviteler (tamamı değil)
      'activities': activities.window,
      'routines_by_weekday': routines.byWeekday,
      'sport_plans_by_weekday': await _sportPlans(),
      'finance_summary': await _finance(today),
      'notes_summary': await _notes(),
    };
  }

  static Future<
    ({List<Map<String, dynamic>> today, List<Map<String, dynamic>> window})
  >
  _activities(DateTime now, String todayKey) async {
    final from = dateKey(now.subtract(const Duration(days: activityDaysBack)));
    final to = dateKey(now.add(const Duration(days: activityDaysAhead)));
    final window = <Map<String, dynamic>>[];
    for (final item in await UserStore.readList('activities')) {
      if (item is! Map) continue;
      final date = asString(item['date']);
      // ISO tarih anahtarları sözlük sırasıyla da tarih sırasındadır.
      if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
      window.add({
        'date': date,
        'title': asString(item['title']),
        'hour': asInt(item['hour']) ?? 0,
        'minute': asInt(item['minute']) ?? 0,
        'reminder': asBool(item['reminder']),
      });
    }
    window.sort((a, b) {
      final byDate = (a['date'] as String).compareTo(b['date'] as String);
      if (byDate != 0) return byDate;
      return ((a['hour'] as int) * 60 + (a['minute'] as int)).compareTo(
        (b['hour'] as int) * 60 + (b['minute'] as int),
      );
    });
    final limited = window.take(maxActivities).toList();
    return (
      today: limited.where((a) => a['date'] == todayKey).toList(),
      window: limited,
    );
  }

  static Future<
    ({List<Map<String, dynamic>> today, Map<String, dynamic> byWeekday})
  >
  _routines(DateTime now) async {
    final todayIndex = now.weekday - 1; // 0 = Pazartesi
    final today = <Map<String, dynamic>>[];
    final byWeekday = <String, dynamic>{};
    final data = await UserStore.readMap('routines');
    for (final entry in data.entries) {
      final day = int.tryParse(entry.key);
      if (day == null || day < 0 || day > 6 || entry.value is! List) continue;
      final list = <Map<String, dynamic>>[];
      for (final item in entry.value as List) {
        if (item is! Map) continue;
        final routine = {
          'weekday': day,
          'title': asString(item['title']),
          'hour': asInt(item['hour']) ?? 8,
          'minute': asInt(item['minute']) ?? 0,
          'reminder': asBool(item['reminder']),
        };
        list.add(routine);
        if (day == todayIndex) today.add(routine);
      }
      byWeekday['$day'] = list;
    }
    return (today: today, byWeekday: byWeekday);
  }

  static Future<Map<String, dynamic>?> _sportPlans() async {
    final data = await UserStore.readMap('sport_plans');
    if (data.isEmpty) return null;
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final plan = entry.value;
      if (plan is! Map) continue;
      final exercises = <Map<String, dynamic>>[];
      final raw = plan['exercises'];
      if (raw is List) {
        for (final ex in raw) {
          if (ex is! Map) continue;
          exercises.add({
            'name': asString(ex['name']),
            'reps': asInt(ex['reps']),
            'sets': asInt(ex['sets']),
          });
        }
      }
      result[entry.key] = {
        'region': asString(plan['region']),
        'exercises': exercises,
      };
    }
    return result;
  }

  /// Toplamlar + "bu hafta/bugün ne kadar harcadım" gibi sorular için dönemsel harcama
  /// ve son işlemler.
  static Future<Map<String, dynamic>?> _finance(DateTime now) async {
    final list = await UserStore.readList('finance_transactions');
    if (list.isEmpty) return null;

    final todayKey = dateKey(now);
    final weekStart = dateKey(weekDaysOf(now).first);
    final monthPrefix = todayKey.substring(0, 7);
    final since = dateKey(now.subtract(const Duration(days: transactionDays)));

    var income = 0.0, expense = 0.0;
    var spentToday = 0.0, spentThisWeek = 0.0, spentThisMonth = 0.0;
    final recent = <Map<String, dynamic>>[];

    for (final item in list) {
      if (item is! Map) continue;
      final amount = asDouble(item['amount']) ?? 0;
      final isIncome = normalizeTxType(item['type']) == 'gelir';
      final date = asString(item['date']);
      if (isIncome) {
        income += amount;
      } else {
        expense += amount;
        if (date == todayKey) spentToday += amount;
        if (date.compareTo(weekStart) >= 0 && date.compareTo(todayKey) <= 0) {
          spentThisWeek += amount;
        }
        if (date.startsWith(monthPrefix)) spentThisMonth += amount;
      }
      if (date.compareTo(since) >= 0) {
        recent.add({
          'date': date,
          'type': isIncome ? 'income' : 'expense',
          'amount': amount,
          'title': asString(item['title']),
          'category': asString(item['category']),
        });
      }
    }
    recent.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return {
      'total_income': income,
      'total_expense': expense,
      'net': income - expense,
      'transaction_count': list.length,
      'spent_today': spentToday,
      'spent_this_week': spentThisWeek,
      'spent_this_month': spentThisMonth,
      'recent_transactions': recent.take(maxRecentTransactions).toList(),
    };
  }

  /// Not başlıkları ve kısa önizleme (içeriğin tamamı gönderilmez).
  static Future<List<Map<String, String>>> _notes() async {
    final result = <Map<String, String>>[];
    for (final item in (await UserStore.readList('notes_v2')).reversed) {
      if (item is! Map) continue;
      final body = asString(item['body']);
      result.add({
        'title': asString(item['title']),
        'preview': body.length > notePreviewLength
            ? '${body.substring(0, notePreviewLength - 3)}...'
            : body,
      });
      if (result.length >= maxNotes) break; // en yeni notlar
    }
    return result;
  }
}
