import 'format.dart';
import 'user_store.dart';

typedef ReminderScheduler =
    Future<void> Function(int id, String title, DateTime when);
typedef RoutineReminderScheduler =
    Future<void> Function(
      int id,
      String title,
      int weekdayMondayFirst,
      int hour,
      int minute,
    );

int? asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt();
  }
  return null;
}

double? asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is String) return v.trim().toLowerCase() == 'true';
  return false;
}

/// İşlem tipini uygulamanın kaydettiği biçime çevirir: 'gelir' | 'gider'.
/// (Eski/AI kayıtlarındaki 'income'/'expense' değerleri de kabul edilir.)
String normalizeTxType(dynamic v) {
  final t = asString(v).toLowerCase();
  return (t == 'gelir' || t == 'income') ? 'gelir' : 'gider';
}

String asString(dynamic v) =>
    v is String ? v.trim() : (v == null ? '' : v.toString().trim());

/// Asistanın (AI) önerdiği action'ları doğrulayıp kullanıcının yerel verisine uygular.
/// Her metot hata mesajı döner; başarılıysa `null`.
class AssistantActions {
  AssistantActions({
    required this.nextNotificationId,
    required this.scheduleActivity,
    required this.scheduleRoutine,
  });

  final int Function() nextNotificationId;
  final ReminderScheduler scheduleActivity;
  final RoutineReminderScheduler scheduleRoutine;

  Future<String?> apply(Map<String, dynamic> action) async {
    final type = action['type'];
    final payload = action['payload'];
    if (type is! String || payload is! Map) return 'Geçersiz action biçimi.';
    final data = Map<String, dynamic>.from(payload);
    try {
      switch (type) {
        case 'add_activity':
          return await _addActivity(data);
        case 'add_routine':
          return await _addRoutine(data);
        case 'add_finance_transaction':
          return await _addFinance(data);
        case 'add_note':
          return await _addNote(data);
        case 'set_sport_plan_for_day':
          return await _setSportPlan(data);
        default:
          return 'Bilinmeyen action: $type';
      }
    } catch (e) {
      return 'Kayıt eklenemedi: $e';
    }
  }

  static bool _validTime(int h, int m) =>
      h >= 0 && h <= 23 && m >= 0 && m <= 59;

  static DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!),
        mo = int.parse(m.group(2)!),
        d = int.parse(m.group(3)!);
    final date = DateTime(y, mo, d);
    // 31 Şubat gibi taşan tarihleri reddet.
    return (date.year == y && date.month == mo && date.day == d) ? date : null;
  }

  Future<String?> _addActivity(Map<String, dynamic> p) async {
    final title = asString(p['title']);
    final date = _parseDate(asString(p['date']));
    final hour = asInt(p['hour']) ?? 0;
    final minute = asInt(p['minute']) ?? 0;
    final reminder = asBool(p['reminder']);
    if (title.isEmpty) return 'Aktivite başlığı boş.';
    if (date == null) return 'Aktivite tarihi geçersiz.';
    if (!_validTime(hour, minute)) return 'Aktivite saati geçersiz.';

    final list = await UserStore.readList('activities');
    int? notificationId;
    if (reminder) {
      notificationId = nextNotificationId();
      await scheduleActivity(
        notificationId,
        title,
        DateTime(date.year, date.month, date.day, hour, minute),
      );
    }
    list.add({
      'date': dateKey(date),
      'title': title,
      'hour': hour,
      'minute': minute,
      'reminder': reminder,
      'notificationId': notificationId,
    });
    await UserStore.writeJson('activities', list);
    return null;
  }

  Future<String?> _addRoutine(Map<String, dynamic> p) async {
    final weekday = asInt(p['weekday']);
    final title = asString(p['title']);
    final hour = asInt(p['hour']) ?? 8;
    final minute = asInt(p['minute']) ?? 0;
    final reminder = asBool(p['reminder']);
    if (weekday == null || weekday < 0 || weekday > 6) {
      return 'Rutin günü geçersiz.';
    }
    if (title.isEmpty) return 'Rutin başlığı boş.';
    if (!_validTime(hour, minute)) return 'Rutin saati geçersiz.';

    final data = await UserStore.readMap('routines');
    final key = '$weekday';
    final list = (data[key] as List<dynamic>?)?.toList() ?? <dynamic>[];

    int? notificationId;
    if (reminder) {
      notificationId = nextNotificationId();
      await scheduleRoutine(notificationId, title, weekday + 1, hour, minute);
    }
    list.add({
      'title': title,
      'hour': hour,
      'minute': minute,
      'reminder': reminder,
      'notificationId': notificationId,
    });
    data[key] = list;
    data.putIfAbsent('completions', () => <String, dynamic>{});
    await UserStore.writeJson('routines', data);
    return null;
  }

  Future<String?> _addFinance(Map<String, dynamic> p) async {
    final kind = asString(p['kind']);
    final amount = asDouble(p['amount']);
    final title = asString(p['title']);
    final date = _parseDate(asString(p['date']));
    if (amount == null || amount <= 0) return 'Tutar geçersiz.';
    if (title.isEmpty) return 'İşlem başlığı boş.';
    if (date == null) return 'İşlem tarihi geçersiz.';

    final list = await UserStore.readList('finance_transactions');
    list.add({
      'type': normalizeTxType(kind),
      'amount': amount,
      'title': title,
      'date': dateKey(date),
      'category': asString(p['category']).isEmpty
          ? 'Diğer'
          : asString(p['category']),
    });
    await UserStore.writeJson('finance_transactions', list);
    return null;
  }

  Future<String?> _addNote(Map<String, dynamic> p) async {
    final title = asString(p['title']);
    final body = asString(p['body']);
    if (title.isEmpty && body.isEmpty) return 'Not boş.';

    final list = await UserStore.readList('notes_v2');
    list.add({'title': title, 'body': body});
    await UserStore.writeJson('notes_v2', list);
    return null;
  }

  Future<String?> _setSportPlan(Map<String, dynamic> p) async {
    final weekday = asInt(p['weekday']);
    final region = asString(p['region']);
    final raw = p['exercises'];
    if (weekday == null || weekday < 0 || weekday > 6) {
      return 'Spor planı günü geçersiz.';
    }

    final exercises = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final ex in raw) {
        if (ex is! Map) continue;
        final name = asString(ex['name']);
        if (name.isEmpty) continue;
        exercises.add({
          'name': name,
          'reps': asInt(ex['reps']) ?? 12,
          'sets': asInt(ex['sets']) ?? 3,
        });
      }
    }

    final data = await UserStore.readMap('sport_plans');
    data['$weekday'] = {
      'region': region.isEmpty ? 'Seçilmedi' : region,
      'exercises': exercises,
    };
    await UserStore.writeJson('sport_plans', data);
    return null;
  }
}
