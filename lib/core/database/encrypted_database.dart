import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Abre la base cifrada con SQLCipher. Si encuentra una base en texto plano
/// (versiones de desarrollo previas al cifrado) la migra una sola vez.
QueryExecutor openEncrypted(
  Future<File> Function() locate,
  Future<String> Function() hexKey,
) => LazyDatabase(() async {
  final file = await locate();
  final key = await hexKey();
  await file.parent.create(recursive: true);
  if (await file.exists() && await isPlainSqlite(file)) {
    await migratePlainToEncrypted(file, key);
  }
  return NativeDatabase(file, setup: (raw) => raw.applyKey(key));
});

extension ApplyKey on Database {
  void applyKey(String hexKey) {
    execute('''PRAGMA key = "x'$hexKey'";''');
    // Falla temprano (y con un mensaje claro) si la clave no corresponde.
    select('SELECT count(*) FROM sqlite_master');
  }
}

/// Un archivo SQLite sin cifrar empieza con la cabecera «SQLite format 3\0».
Future<bool> isPlainSqlite(File f) async {
  if (await f.length() < 16) return false;
  final raf = await f.open();
  try {
    final head = await raf.read(16);
    return String.fromCharCodes(head.take(15)) == 'SQLite format 3' &&
        head[15] == 0;
  } finally {
    await raf.close();
  }
}

/// Exporta la base plana a una cifrada y reemplaza el archivo (conserva
/// `user_version`, necesario para las migraciones de Drift).
Future<void> migratePlainToEncrypted(File file, String hexKey) async {
  final tmp = File('${file.path}.enc');
  if (await tmp.exists()) await tmp.delete();
  final plain = sqlite3.open(file.path);
  try {
    final version = plain.select('PRAGMA user_version').first.values.first;
    plain.execute('''ATTACH DATABASE '${tmp.path}' AS enc KEY "x'$hexKey'";''');
    plain.select("SELECT sqlcipher_export('enc')");
    plain.execute('PRAGMA enc.user_version = $version');
    plain.execute('DETACH DATABASE enc');
  } finally {
    plain.close();
  }
  // Se conserva la copia plana hasta confirmar que la nueva abre.
  final backup = File('${file.path}.plain-bak');
  await file.rename(backup.path);
  try {
    await tmp.rename(file.path);
    final check = sqlite3.open(file.path)..applyKey(hexKey);
    check.close();
  } catch (_) {
    if (await file.exists()) await file.delete();
    await backup.rename(file.path);
    rethrow;
  }
  await backup.delete();
}
