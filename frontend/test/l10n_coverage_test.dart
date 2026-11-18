import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/l10n/en_translations.dart';

/// Kaynak koddaki `'metin'.tr(context)` çağrılarının hepsinin İngilizce karşılığı olmalı.
Set<String> _trKeysInSource() {
  final keys = <String>{};
  // Yan yana yazılmış literal parçaları ('a' 'b') tek metin sayılır.
  final call = RegExp(r"((?:'(?:[^'\\]|\\.)*'\s*)+)\.tr\(");
  final piece = RegExp(r"'((?:[^'\\]|\\.)*)'");
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    for (final m in call.allMatches(file.readAsStringSync())) {
      final joined = piece
          .allMatches(m.group(1)!)
          .map((p) => p.group(1)!)
          .join()
          .replaceAll(r"\'", "'")
          .replaceAll(r'\n', '\n');
      // Dinamik (interpolasyonlu) metinler çeviri anahtarı değildir.
      if (joined.contains(r'$')) continue;
      keys.add(joined);
    }
  }
  return keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kodda .tr() ile işaretlenen her metnin İngilizce çevirisi var', () {
    final missing =
        _trKeysInSource().where((k) => !enTranslations.containsKey(k)).toList()
          ..sort();
    expect(missing, isEmpty, reason: 'Eksik çeviriler:\n${missing.join('\n')}');
  });

  test(
    'çeviri tablosunda artık kullanılmayan (eski özelliklerden kalan) anahtar yok',
    () {
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final stale =
          enTranslations.keys
              .where(
                (k) =>
                    !source.contains(k) &&
                    !source.contains(k.replaceAll("'", r"\'")),
              )
              .toList()
            ..sort();
      expect(
        stale,
        isEmpty,
        reason: 'Kullanılmayan çeviriler:\n${stale.join('\n')}',
      );
    },
  );

  test('çeviri tablosunda boş ya da aynı metne çevrilen değer yok', () {
    final bad = enTranslations.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    expect(bad, isEmpty);
  });

  test('ana sayfa görselleri pakete gömülü', () async {
    for (final name in [
      'activities',
      'routines',
      'sport',
      'finance',
      'notes',
    ]) {
      final data = await rootBundle.load('assets/home/$name.jpg');
      expect(data.lengthInBytes, greaterThan(10000), reason: name);
    }
  });
}
