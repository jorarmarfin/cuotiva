import 'dart:io';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Spike Fase 4: SQLCipher funciona con Drift y el esquema real.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cuotiva_cipher'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('el motor es SQLCipher', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final v = db.select('PRAGMA cipher_version');
    expect(v, isNotEmpty, reason: 'sqlite3 no se compiló con SQLCipher');
  });

  test(
    'BD cifrada: abre con clave, falla sin ella y no hay texto plano',
    () async {
      final file = File('${tmp.path}/c.db');
      NativeDatabase open(String key) => NativeDatabase(
        file,
        setup: (raw) => raw.execute("PRAGMA key = \"x'$key'\";"),
      );
      final key = 'a1' * 32;

      final db = AppDatabase(open(key));
      await db
          .into(db.spaces)
          .insert(
            SpacesCompanion.insert(
              id: 's1',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              name: 'SecretoVisible',
              color: 1,
            ),
          );
      await db.close();

      expect(
        String.fromCharCodes(file.readAsBytesSync()).contains('SecretoVisible'),
        isFalse,
      );

      final ok = AppDatabase(open(key));
      expect((await ok.select(ok.spaces).get()).single.name, 'SecretoVisible');
      await ok.close();

      final bad = AppDatabase(open('b2' * 32));
      await expectLater(bad.select(bad.spaces).get(), throwsA(anything));
      await bad.close().catchError((_) {});
    },
  );
}
