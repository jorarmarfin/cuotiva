import 'package:cuotiva/core/database/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v3 → v4: agrega payments.installment_id', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
  });

  test('v1 → v4, v2 → v4: el esquema coincide con el esperado', () async {
    for (final from in [1, 2]) {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    }
  });

  test('v1 → v2 conserva los datos existentes', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    const ts = 1763337600; // 2025-11-17 en segundos
    raw.execute(
      'INSERT INTO spaces (id, created_at, updated_at, name, type, color, icon) '
      "VALUES ('s1', $ts, $ts, 'Negocio', 'business', 4285549785, 'store')",
    );
    raw.execute(
      "INSERT INTO contacts (id, created_at, updated_at, display_name) VALUES ('c1', $ts, $ts, 'Rosa')",
    );
    raw.execute(
      "INSERT INTO collections (id, created_at, updated_at, space_id, title) VALUES ('k1', $ts, $ts, 's1', 'Buzos')",
    );
    raw.execute(
      'INSERT INTO receivables (id, created_at, updated_at, collection_id, contact_id, principal_minor) '
      "VALUES ('r1', $ts, $ts, 'k1', 'c1', 12000)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final receivables = await db.select(db.receivables).get();
    expect(receivables.single.principalMinor, 12000);
    // Las tablas nuevas existen y aceptan datos.
    final now = DateTime(2026, 11, 17);
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            id: 'p1',
            createdAt: now,
            updatedAt: now,
            receivableId: 'r1',
            amountMinor: 3000,
            occurredAt: now,
          ),
        );
    expect(
      (await db.select(db.payments).get()).single.status,
      'pending_verification',
    );
  });
  test('§12.12 v2 → v3 conserva historial y habilita rendiciones', () async {
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    const ts = 1763337600;
    raw.execute(
      'INSERT INTO spaces (id, created_at, updated_at, name, type, color, icon) '
      "VALUES ('s1', $ts, $ts, 'Capilla', 'chapel', 1, 'church')",
    );
    raw.execute(
      "INSERT INTO contacts (id, created_at, updated_at, display_name) VALUES ('c1', $ts, $ts, 'Rosa')",
    );
    raw.execute(
      'INSERT INTO collections (id, created_at, updated_at, space_id, title, funds_ownership) '
      "VALUES ('k1', $ts, $ts, 's1', 'Pasajes', 'third_party')",
    );
    raw.execute(
      'INSERT INTO receivables (id, created_at, updated_at, collection_id, contact_id, principal_minor) '
      "VALUES ('r1', $ts, $ts, 'k1', 'c1', 80000)",
    );
    raw.execute(
      'INSERT INTO payments (id, created_at, updated_at, receivable_id, amount_minor, occurred_at, status) '
      "VALUES ('p1', $ts, $ts, 'r1', 60000, $ts, 'confirmed')",
    );
    raw.execute(
      'INSERT INTO audit_logs (id, created_at, updated_at, entity_type, entity_id, action, occurred_at) '
      "VALUES ('a1', $ts, $ts, 'payment', 'p1', 'register', $ts)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    expect((await db.select(db.payments).get()).single.amountMinor, 60000);
    expect(await db.select(db.auditLogs).get(), hasLength(1));
    final now = DateTime(2026, 11, 17);
    await db
        .into(db.settlements)
        .insert(
          SettlementsCompanion.insert(
            id: 'st1',
            createdAt: now,
            updatedAt: now,
            collectionId: 'k1',
            amountMinor: 50000,
            occurredAt: now,
          ),
        );
    expect((await db.select(db.settlements).get()).single.status, 'confirmed');
  });
}
