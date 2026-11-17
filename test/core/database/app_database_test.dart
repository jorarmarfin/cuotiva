import 'package:cuotiva/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 17);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedBase() async {
    await db
        .into(db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 's1',
            createdAt: now,
            updatedAt: now,
            name: 'Negocio',
            color: 0xFF6D28D9,
          ),
        );
    await db
        .into(db.contacts)
        .insert(
          ContactsCompanion.insert(
            id: 'c1',
            createdAt: now,
            updatedAt: now,
            displayName: 'Rosa',
          ),
        );
    await db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            id: 'k1',
            createdAt: now,
            updatedAt: now,
            spaceId: 's1',
            title: 'Buzos',
          ),
        );
  }

  Future<void> insertReceivable(int principal, {String id = 'r1'}) => db
      .into(db.receivables)
      .insert(
        ReceivablesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          collectionId: 'k1',
          contactId: 'c1',
          principalMinor: principal,
        ),
      );

  test('foreign keys activas: cobro sin espacio falla', () async {
    expect(
      db
          .into(db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: 'x',
              createdAt: now,
              updatedAt: now,
              spaceId: 'nope',
              title: 'T',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('importe de obligación debe ser positivo', () async {
    await seedBase();
    expect(insertReceivable(0), throwsA(isA<Exception>()));
    await insertReceivable(12000);
    expect(
      (await db.select(db.receivables).get()).single.principalMinor,
      12000,
    );
  });

  test('un contacto no se duplica en el mismo cobro', () async {
    await seedBase();
    await insertReceivable(100);
    expect(insertReceivable(200, id: 'r2'), throwsA(isA<Exception>()));
  });

  test('mismo contacto en varios cobros/espacios', () async {
    await seedBase();
    await db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            id: 'k2',
            createdAt: now,
            updatedAt: now,
            spaceId: 's1',
            title: 'Otro',
          ),
        );
    await insertReceivable(100);
    await db
        .into(db.receivables)
        .insert(
          ReceivablesCompanion.insert(
            id: 'r2',
            createdAt: now,
            updatedAt: now,
            collectionId: 'k2',
            contactId: 'c1',
            principalMinor: 50,
          ),
        );
    expect(await db.select(db.receivables).get(), hasLength(2));
  });

  test('funds_ownership inválido rechazado', () async {
    await seedBase();
    expect(
      db
          .into(db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: 'k3',
              createdAt: now,
              updatedAt: now,
              spaceId: 's1',
              title: 'X',
              fundsOwnership: const Value('foo'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
