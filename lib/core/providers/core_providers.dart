import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/encrypted_database.dart';
import '../security/db_key_service.dart';

final dbKeyServiceProvider = Provider<DbKeyService>(
  (_) => DbKeyService(const SecureDbKeyStore()),
);

Future<File> locateDatabaseFile() async => File(
  p.join((await getApplicationDocumentsDirectory()).path, 'cuotiva.sqlite'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final keys = ref.watch(dbKeyServiceProvider);
  final db = AppDatabase(openEncrypted(locateDatabaseFile, keys.getOrCreate));
  ref.onDispose(db.close);
  return db;
});

/// Reloj inyectable (facilita tests de vencimientos).
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final uuidProvider = Provider<Uuid>((_) => const Uuid());
