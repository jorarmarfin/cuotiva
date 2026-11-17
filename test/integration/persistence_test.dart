import 'dart:io';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/database/encrypted_database.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/core/security/crypto_service.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/attachments_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// §12.10: cerrar y reabrir la app conserva datos e imágenes, usando la base
/// SQLCipher y los comprobantes cifrados reales en disco.
void main() {
  test(
    'reabrir la app conserva datos, auditoría e imágenes cifradas',
    () async {
      final dir = Directory.systemTemp.createTempSync('cuotiva_persist');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbFile = File(p.join(dir.path, 'cuotiva.sqlite'));
      final key = 'cd' * 32;
      final cipher = AeadCipher.derive(List.filled(32, 7), 'attachments');
      DateTime clock() => DateTime(2026, 11, 17, 10);
      const uuid = Uuid();
      final photo = List<int>.generate(500, (i) => (i * 13) % 256);

      AppDatabase open() =>
          AppDatabase(openEncrypted(() async => dbFile, () async => key));
      AttachmentsRepository atts(AppDatabase db) => AttachmentsRepository(
        db,
        AuditService(db, uuid, clock),
        uuid,
        clock,
        () async => dir,
        () async => cipher,
      );

      // Sesión 1
      var db = open();
      final audit = AuditService(db, uuid, clock);
      final payments = PaymentsRepository(db, audit, uuid, clock);
      final space = await SpacesRepository(
        db,
        audit,
        uuid,
        clock,
      ).create(name: 'Negocio', color: 1);
      final c = await ContactsRepository(
        db,
        audit,
        uuid,
        clock,
      ).create(displayName: 'Rosa');
      final col = await CollectionsRepository(
        db,
        audit,
        uuid,
        clock,
      ).create(spaceId: space.id, title: 'Buzos');
      final r =
          await ReceivablesRepository(
            db,
            audit,
            uuid,
            clock,
            collected: payments.confirmedTotal,
          ).create(
            collectionId: col.id,
            contactId: c.id,
            principal: Money.parse('120'),
          );
      final pay = await payments.register(
        receivableId: r.id,
        amount: Money.parse('40'),
        confirmNow: false,
      );
      final src = File(p.join(dir.path, 'yape.jpg'))..writeAsBytesSync(photo);
      await atts(db).add(paymentId: pay.id, source: src);
      final auditCount = (await db.select(db.auditLogs).get()).length;
      await db.close();

      // Sesión 2: «reabrir la app»
      db = open();
      addTearDown(db.close);
      expect((await db.select(db.spaces).get()).single.name, 'Negocio');
      expect(
        (await db.select(db.receivables).get()).single.principalMinor,
        12000,
      );
      final p2 = (await db.select(db.payments).get()).single;
      expect(p2.status, 'pending_verification');
      expect((await db.select(db.auditLogs).get()), hasLength(auditCount));
      final a = (await db.select(db.attachments).get()).single;
      final repo = atts(db);
      expect(await repo.readBytes(a), photo);
      expect(await repo.verify(a), isTrue);
      // En disco no hay nada legible.
      expect(await isPlainSqlite(dbFile), isFalse);
      expect(
        AeadCipher.looksEncrypted(await (await repo.fileOf(a)).readAsBytes()),
        isTrue,
      );
    },
  );
}
