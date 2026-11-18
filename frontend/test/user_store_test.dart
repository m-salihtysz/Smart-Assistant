import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/services/user_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser(null);
  });

  test('anahtar, oturum yokken erişimde hata verir', () {
    expect(() => UserStore.key('notes_v2'), throwsStateError);
  });

  test('farklı kullanıcılar birbirinin verisini görmez', () async {
    UserStore.setUser('a@example.com');
    await UserStore.writeJson('notes_v2', [
      {'title': 'a-notu'},
    ]);

    UserStore.setUser('B@Example.com');
    expect(await UserStore.readList('notes_v2'), isEmpty);
    await UserStore.writeJson('notes_v2', [
      {'title': 'b-notu'},
    ]);

    UserStore.setUser('a@example.com');
    expect((await UserStore.readList('notes_v2')).single['title'], 'a-notu');

    // E-posta büyük/küçük harf duyarsız
    UserStore.setUser('b@example.com');
    expect((await UserStore.readList('notes_v2')).single['title'], 'b-notu');
  });

  test('bozuk JSON boş değer döner', () async {
    UserStore.setUser('a@example.com');
    await UserStore.setString('routines', '{bozuk');
    expect(await UserStore.readMap('routines'), isEmpty);
    expect(await UserStore.readList('routines'), isEmpty);
  });

  test('eski öneksiz veri ilk kullanıcıya taşınır ve silinir', () async {
    SharedPreferences.setMockInitialValues({'notes_v2': '[{"title":"eski"}]'});
    UserStore.setUser('ilk@example.com');
    await UserStore.migrateLegacyData();
    expect((await UserStore.readList('notes_v2')).single['title'], 'eski');

    UserStore.setUser('ikinci@example.com');
    await UserStore.migrateLegacyData();
    expect(await UserStore.readList('notes_v2'), isEmpty);
  });

  test('clearAll yalnızca aktif kullanıcının verisini siler', () async {
    UserStore.setUser('a@example.com');
    await UserStore.writeJson('activities', [1]);
    UserStore.setUser('b@example.com');
    await UserStore.writeJson('activities', [2]);

    await UserStore.clearAll();
    expect(await UserStore.readList('activities'), isEmpty);
    UserStore.setUser('a@example.com');
    expect(await UserStore.readList('activities'), [1]);
  });
}
