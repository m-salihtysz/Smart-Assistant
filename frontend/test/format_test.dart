import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/services/format.dart';

void main() {
  test('formatDateKey ISO anahtarını gün.ay.yıl yapar', () {
    expect(formatDateKey('2026-03-06'), '06.03.2026');
    expect(formatDateKey('2026-3-6'), '06.03.2026');
    expect(formatDateKey('bozuk'), 'bozuk');
  });

  test('formatDate sıfır dolgulu', () {
    expect(formatDate(DateTime(1999, 5, 1)), '01.05.1999');
  });

  test('formatMoney binlik ayraç ve işaret', () {
    expect(formatMoney(0), '₺0');
    expect(formatMoney(999), '₺999');
    expect(formatMoney(15000), '₺15.000');
    expect(formatMoney(1234567), '₺1.234.567');
    expect(formatMoney(150.5), '₺151');
    expect(formatMoney(-2500), '-₺2.500');
    expect(formatMoney(2500, signed: true), '+₺2.500');
  });
}
