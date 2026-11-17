import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos local de Cuotiva.
/// El `QueryExecutor` se inyecta: SQLCipher en la app (`openEncrypted`),
/// en memoria en tests.
@DriftDatabase(
  tables: [
    Spaces,
    Contacts,
    Collections,
    Receivables,
    Installments,
    AuditLogs,
    AppSettings,
    Payments,
    PaymentAllocations,
    Attachments,
    Settlements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
      await _createPaymentIndexes();
      await _createSettlementIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(payments);
        await m.createTable(paymentAllocations);
        await m.createTable(attachments);
        await _createPaymentIndexes();
      }
      if (from < 3) {
        await m.createTable(settlements);
        await _createSettlementIndexes();
      }
      // Desde v1 `payments` ya se crea con la columna (createTable usa el esquema actual).
      if (from >= 2 && from < 4) {
        await m.addColumn(payments, payments.installmentId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v3: rendiciones.
  Future<void> _createSettlementIndexes() => customStatement(
    'CREATE INDEX idx_settlements_collection ON settlements(collection_id)',
  );

  /// v2: pagos, asignaciones y adjuntos.
  Future<void> _createPaymentIndexes() async {
    for (final sql in const [
      'CREATE INDEX idx_payments_receivable ON payments(receivable_id)',
      'CREATE INDEX idx_payments_occurred ON payments(occurred_at)',
      'CREATE INDEX idx_allocations_payment ON payment_allocations(payment_id)',
      'CREATE INDEX idx_allocations_installment ON payment_allocations(installment_id)',
      'CREATE INDEX idx_attachments_payment ON attachments(payment_id)',
    ]) {
      await customStatement(sql);
    }
  }

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

extension WatchTables on AppDatabase {
  /// Emite cuando cambia cualquiera de [tables].
  ///
  /// Drift reutiliza un mismo stream para consultas con idéntico SQL y
  /// argumentos, IGNORANDO `readsFrom`: dos `customSelect('SELECT 1')` con
  /// tablas distintas compartían el primer conjunto y el segundo dejaba de
  /// refrescarse. Por eso el SQL lleva el nombre de las tablas.
  Stream<void> watchTables(Set<TableInfo<Table, Object?>> tables) {
    final names = tables.map((t) => t.actualTableName).toList()..sort();
    return customSelect(
      'SELECT 1 /* ${names.join(',')} */',
      readsFrom: tables,
    ).watch().map((_) {});
  }
}
