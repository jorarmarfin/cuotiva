import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos local de Cuotiva.
/// El `QueryExecutor` es inyectable para tests (en memoria) y para
/// migrar a SQLCipher en la Fase 4.
@DriftDatabase(
  tables: [
    Spaces,
    Contacts,
    Collections,
    Receivables,
    Installments,
    AuditLogs,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'cuotiva'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    for (final sql in const [
      'CREATE INDEX idx_collections_space ON collections(space_id)',
      'CREATE INDEX idx_receivables_collection ON receivables(collection_id)',
      'CREATE INDEX idx_receivables_contact ON receivables(contact_id)',
      'CREATE INDEX idx_installments_due ON installments(due_at)',
      'CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id)',
    ]) {
      await customStatement(sql);
    }
  }
}
