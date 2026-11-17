import 'dart:io';
import 'dart:math';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/encrypted_database.dart';
import 'package:cuotiva/core/security/db_key_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemStore implements DbKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String hexKey) async => value = hexKey;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cuotiva_enc'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('DbKeyService crea una clave de 32 bytes y la reutiliza', () async {
    final store = _MemStore();
    final svc = DbKeyService(store, random: Random(1));
    final k1 = await svc.getOrCreate();
    expect(k1, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await svc.getOrCreate(), k1);
    store.value = 'corrupta';
    expect(await svc.getOrCreate(), isNot('corrupta'));
  });

  test(
    'migra una base en texto plano a cifrada conservando datos y versión',
    () async {
      final file = File('${tmp.path}/cuotiva.sqlite');
      final plain = AppDatabase(NativeDatabase(file));
      await plain
          .into(plain.spaces)
          .insert(
            SpacesCompanion.insert(
              id: 's1',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              name: 'Antiguo',
              color: 1,
            ),
          );
      await plain.close();
      expect(await isPlainSqlite(file), isTrue);

      final key = 'ab' * 32;
      final db = AppDatabase(openEncrypted(() async => file, () async => key));
      expect((await db.select(db.spaces).get()).single.name, 'Antiguo');
      await db.close();

      expect(await isPlainSqlite(file), isFalse);
      expect(File('${file.path}.plain-bak').existsSync(), isFalse);
      expect(
        String.fromCharCodes(file.readAsBytesSync()),
        isNot(contains('Antiguo')),
      );

      // Reabrir no vuelve a migrar y no dispara migraciones de esquema.
      final again = AppDatabase(
        openEncrypted(() async => file, () async => key),
      );
      expect((await again.select(again.spaces).get()), hasLength(1));
      await again.close();
    },
  );

  test('base nueva: se crea cifrada', () async {
    final file = File('${tmp.path}/sub/nueva.sqlite');
    final db = AppDatabase(
      openEncrypted(() async => file, () async => 'cd' * 32),
    );
    await db.select(db.spaces).get();
    await db.close();
    expect(await isPlainSqlite(file), isFalse);
  });
}
