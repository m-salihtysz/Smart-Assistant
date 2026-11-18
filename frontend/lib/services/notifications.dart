import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'assistant_actions.dart';
import 'user_store.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();
int _notificationIdCounter = 1000;
bool _notificationsEnabled = true;

bool get areNotificationsEnabled => _notificationsEnabled;

Future<void> loadNotificationPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  // Her cihaz farklı bir aralıktan başlar: bulutla eşitlenen hatırlatıcıların kimlikleri
  // başka bir cihazın yeni kimlikleriyle çakışıp birbirini ezmesin.
  _notificationIdCounter =
      prefs.getInt('notification_id_counter') ??
      1000 + Random().nextInt(1 << 30);
  _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
}

Future<void> initNotifications() async {
  tz_data.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  // İzin açılışta değil, kullanıcı ilk hatırlatıcıyı kurarken istenir.
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (_) {},
  );
}

/// Bildirim iznini ister (iOS'ta yalnızca ilk seferde sistem penceresi çıkar).
/// İzin verildiyse ya da platform izin gerektirmiyorsa `true` döner.
Future<bool> ensureNotificationPermission() async {
  try {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return true;
    return await ios.requestPermissions(alert: true, sound: true) ?? false;
  } catch (_) {
    return true;
  }
}

/// Bildirimleri açar/kapatır. Kapatınca zamanlanmış hepsi iptal edilir;
/// açınca kullanıcının kayıtlı hatırlatıcıları yeniden kurulur.
Future<void> applyNotificationsEnabled(bool value) async {
  _notificationsEnabled = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notifications_enabled', value);
  if (value) {
    if (UserStore.user != null) await rescheduleAllReminders();
  } else {
    await cancelAllReminders();
  }
}

Future<void> cancelAllReminders() => _plugin.cancelAll();

int nextNotificationId() {
  final id = _notificationIdCounter++;
  SharedPreferences.getInstance().then(
    (prefs) => prefs.setInt('notification_id_counter', _notificationIdCounter),
  );
  return id;
}

Future<void> cancelReminderNotification(int id) => _plugin.cancel(id);

Future<void> scheduleActivityReminder(
  int id,
  String title,
  DateTime when,
) async {
  if (!_notificationsEnabled) return;
  if (when.isBefore(DateTime.now())) return;
  if (!await ensureNotificationPermission()) return;
  await _plugin.zonedSchedule(
    id,
    'Hatırlatıcı',
    title,
    tz.TZDateTime.from(when, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'activities',
        'Aktivite hatırlatıcıları',
        channelDescription: 'Aktivite bildirimleri',
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

/// [weekday]: 1 = Pazartesi ... 7 = Pazar. Her hafta tekrar eder.
Future<void> scheduleRoutineReminder(
  int id,
  String title,
  int weekday,
  int hour,
  int minute,
) async {
  if (!_notificationsEnabled) return;
  if (!await ensureNotificationPermission()) return;
  final now = DateTime.now();
  var days = (weekday - now.weekday) % 7;
  if (days == 0 &&
      (now.hour > hour || (now.hour == hour && now.minute >= minute))) {
    days = 7;
  }
  final when = DateTime(now.year, now.month, now.day + days, hour, minute);
  await _plugin.zonedSchedule(
    id,
    'Rutin hatırlatıcı',
    title,
    tz.TZDateTime.from(when, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'routines',
        'Rutin hatırlatıcıları',
        channelDescription: 'Rutin bildirimleri',
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

/// Aktif kullanıcının kayıtlı aktivite ve rutin hatırlatıcılarını yeniden zamanlar
/// (girişte, oturum geri yüklenince ve bildirimler tekrar açılınca).
Future<void> rescheduleAllReminders() async {
  if (!_notificationsEnabled || UserStore.user == null) return;
  try {
    await cancelAllReminders();

    for (final item in await UserStore.readList('activities')) {
      if (item is! Map || !asBool(item['reminder'])) continue;
      final id = asInt(item['notificationId']);
      final date = DateTime.tryParse(asString(item['date']));
      if (id == null || date == null) continue;
      await scheduleActivityReminder(
        id,
        asString(item['title']),
        DateTime(
          date.year,
          date.month,
          date.day,
          asInt(item['hour']) ?? 0,
          asInt(item['minute']) ?? 0,
        ),
      );
    }

    final routines = await UserStore.readMap('routines');
    for (final entry in routines.entries) {
      final dayIndex = int.tryParse(entry.key);
      if (dayIndex == null ||
          dayIndex < 0 ||
          dayIndex > 6 ||
          entry.value is! List) {
        continue;
      }
      for (final item in entry.value as List) {
        if (item is! Map || !asBool(item['reminder'])) continue;
        final id = asInt(item['notificationId']);
        if (id == null) continue;
        await scheduleRoutineReminder(
          id,
          asString(item['title']),
          dayIndex + 1,
          asInt(item['hour']) ?? 8,
          asInt(item['minute']) ?? 0,
        );
      }
    }
  } catch (_) {
    // Bildirim eklentisi hazır değilse (ör. testler) sessizce geç.
  }
}
