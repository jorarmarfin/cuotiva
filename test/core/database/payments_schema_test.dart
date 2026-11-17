import 'package:cuotiva/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 17);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 's',
            createdAt: now,
            updatedAt: now,
            name: 'N',
            color: 1,
          ),
        );
    await db
        .into(db.contacts)
        .insert(
          ContactsCompanion.insert(
            id: 'c',
            createdAt: now,
            updatedAt: now,
            displayName: 'Rosa',
          ),
        );
    await db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            id: 'k',
            createdAt: now,
            updatedAt: now,
            spaceId: 's',
            title: 'T',
          ),
        );
    await db
        .into(db.receivables)
        .insert(
          ReceivablesCompanion.insert(
            id: 'r',
            createdAt: now,
            updatedAt: now,
            collectionId: 'k',
            contactId: 'c',
            principalMinor: 12000,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> pay({
    int amount = 3000,
    String status = 'confirmed',
    String method = 'cash',
    String id = 'p',
  }) => db
      .into(db.payments)
      .insert(
        PaymentsCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          receivableId: 'r',
          amountMinor: amount,
          occurredAt: now,
          status: Value(status),
          method: Value(method),
        ),
      );

  test('pago válido', () async {
    await pay();
    expect((await db.select(db.payments).get()).single.amountMinor, 3000);
  });

  test('rechaza monto no positivo, estado y método inválidos', () async {
    expect(pay(amount: 0), throwsA(isA<Exception>()));
    expect(pay(status: 'paid'), throwsA(isA<Exception>()));
    expect(pay(method: 'bitcoin'), throwsA(isA<Exception>()));
  });

  test('FK: pago sin obligación falla', () async {
    expect(
      db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'x',
              createdAt: now,
              updatedAt: now,
              receivableId: 'nope',
              amountMinor: 1,
              occurredAt: now,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('adjuntos requieren pago existente', () async {
    await pay();
    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'a',
            createdAt: now,
            updatedAt: now,
            paymentId: 'p',
            relativePath: 'attachments/a.jpg',
            mimeType: 'image/jpeg',
            byteSize: 1000,
            checksum: 'abc',
          ),
        );
    expect((await db.select(db.attachments).get()).single.encrypted, isFalse);
  });
}
