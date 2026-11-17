import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Reloj inyectable (facilita tests de vencimientos).
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final uuidProvider = Provider<Uuid>((_) => const Uuid());
