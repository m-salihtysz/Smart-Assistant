/// `2026-03-06` biçimindeki tarih anahtarını `06.03.2026` olarak gösterir.
String formatDateKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(key);
  if (m == null) return key;
  return '${m.group(3)!.padLeft(2, '0')}.${m.group(2)!.padLeft(2, '0')}.${m.group(1)}';
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Tutarı binlik ayraçla biçimlendirir: 15000 -> ₺15.000
String formatMoney(double amount, {bool signed = false}) {
  final negative = amount < 0;
  final digits = amount.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  final sign = negative ? '-' : (signed ? '+' : '');
  return '$sign₺$buf';
}

/// `DateTime` -> `2026-03-06` (veri anahtarı olarak kullanılan biçim).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Verilen günün haftasının Pazartesi–Pazar günleri (gece yarısı).
List<DateTime> weekDaysOf(DateTime day) {
  final today = DateTime(day.year, day.month, day.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

/// Haftanın günleri, Pazartesi'den başlayarak (çeviri için Türkçe anahtarlar).
const List<String> kWeekdayShortTr = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];
