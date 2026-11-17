import 'dart:io';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/core/security/crypto_service.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/attachments_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/payments/domain/payment_errors.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late Directory src;
  late AttachmentsRepository attachments;
  late PaymentsRepository payments;
  late Receivable r;

  DateTime clock() => DateTime(2026, 11, 17);

  File image(String name, [List<int> bytes = const [1, 2, 3, 4, 5]]) =>
      File('${src.path}/$name')..writeAsBytesSync(bytes);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('cuotiva_att_');
    src = Directory.systemTemp.createTempSync('cuotiva_src_');
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    attachments = AttachmentsRepository(
      db,
      audit,
      uuid,
      clock,
      () async => root,
    );
    payments = PaymentsRepository(db, audit, uuid, clock);
    final space = await SpacesRepository(
      db,
      audit,
      uuid,
      clock,
    ).create(name: 'N', color: 1);
    final contact = await ContactsRepository(
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
    ).create(spaceId: space.id, title: 'T');
    r = await ReceivablesRepository(db, audit, uuid, clock).create(
      collectionId: col.id,
      contactId: contact.id,
      principal: Money.parse('120'),
    );
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
    src.deleteSync(recursive: true);
  });

  Future<Payment> pending() => payments.register(
    receivableId: r.id,
    amount: Money.parse('40'),
    method: 'yape',
    confirmNow: false,
  );

  test(
    'copia el archivo al almacenamiento privado con checksum y tamaño',
    () async {
      final p = await pending();
      final a = await attachments.add(
        paymentId: p.id,
        source: image('yape.jpg'),
      );
      expect(a.mimeType, 'image/jpeg');
      expect(a.byteSize, 5);
      expect(a.relativePath, startsWith('attachments/'));
      expect(a.checksum, hasLength(64));
      final stored = await attachments.fileOf(a);
      expect(stored.existsSync(), isTrue);
      expect(
        stored.path,
        startsWith(root.path),
        reason: 'no debe apuntar a la galería',
      );
      expect(await attachments.verify(a), isTrue);
    },
  );

  test('verify detecta archivo alterado o ausente', () async {
    final p = await pending();
    final a = await attachments.add(paymentId: p.id, source: image('a.png'));
    final f = await attachments.fileOf(a);
    f.writeAsBytesSync([9, 9, 9]);
    expect(await attachments.verify(a), isFalse);
    f.deleteSync();
    expect(await attachments.verify(a), isFalse);
  });

  test('varias imágenes por pago', () async {
    final p = await pending();
    await attachments.add(paymentId: p.id, source: image('1.jpg'));
    await attachments.add(paymentId: p.id, source: image('2.png', [7, 7]));
    expect(await attachments.watchByPayment(p.id).first, hasLength(2));
  });

  test('rechaza formato, vacío, inexistente y pago inexistente', () async {
    final p = await pending();
    await expectLater(
      attachments.add(paymentId: p.id, source: image('doc.pdf')),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      attachments.add(paymentId: p.id, source: image('e.jpg', [])),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      attachments.add(paymentId: p.id, source: File('${src.path}/no.jpg')),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      attachments.add(paymentId: 'x', source: image('ok.jpg')),
      throwsA(isA<PaymentException>()),
    );
    expect(
      root.existsSync()
          ? root.listSync(recursive: true).whereType<File>()
          : <File>[],
      isEmpty,
    );
  });

  test('no agrega a pagos anulados/rechazados', () async {
    final p = await pending();
    await payments.reject(p.id);
    await expectLater(
      attachments.add(paymentId: p.id, source: image('a.jpg')),
      throwsA(isA<PaymentException>()),
    );
  });

  test('quitar: solo en pagos por verificar; borra archivo y audita', () async {
    final p = await pending();
    final a = await attachments.add(paymentId: p.id, source: image('a.jpg'));
    final f = await attachments.fileOf(a);
    await attachments.remove(a.id);
    expect(f.existsSync(), isFalse);
    expect(await db.select(db.attachments).get(), isEmpty);
    expect(
      (await db.select(db.auditLogs).get())
          .where((l) => l.entityType == 'attachment')
          .map((l) => l.action),
      ['add', 'remove'],
    );
  });

  test('evidencia de pago confirmado no se puede quitar', () async {
    final p = await pending();
    final a = await attachments.add(paymentId: p.id, source: image('a.jpg'));
    await payments.confirm(p.id);
    await expectLater(
      attachments.remove(a.id),
      throwsA(isA<PaymentException>()),
    );
    expect(await db.select(db.attachments).get(), hasLength(1));
  });
  group('cifrado en disco', () {
    late AttachmentsRepository enc;
    final key = List<int>.generate(32, (i) => i + 1);

    setUp(() {
      const uuid = Uuid();
      enc = AttachmentsRepository(
        db,
        AuditService(db, uuid, clock),
        uuid,
        clock,
        () async => root,
        () async => AeadCipher(key),
      );
    });

    test('el archivo en disco va cifrado y se lee de vuelta igual', () async {
      final p = await pending();
      final bytes = List<int>.generate(200, (i) => i % 256);
      final a = await enc.add(paymentId: p.id, source: image('a.jpg', bytes));
      expect(a.encrypted, isTrue);
      final onDisk = await (await enc.fileOf(a)).readAsBytes();
      expect(AeadCipher.looksEncrypted(onDisk), isTrue);
      expect(onDisk, isNot(bytes));
      expect(await enc.readBytes(a), bytes);
      expect(await enc.verify(a), isTrue);
    });

    test('verify detecta un archivo alterado', () async {
      final p = await pending();
      final a = await enc.add(paymentId: p.id, source: image('a.jpg'));
      final f = await enc.fileOf(a);
      final data = f.readAsBytesSync()..[20] ^= 1;
      f.writeAsBytesSync(data);
      expect(await enc.verify(a), isFalse);
    });

    test('un cifrado no se puede mover a otro adjunto (AAD = id)', () async {
      final p = await pending();
      final a1 = await enc.add(paymentId: p.id, source: image('1.jpg'));
      final a2 = await enc.add(paymentId: p.id, source: image('2.jpg'));
      (await enc.fileOf(a2))
          .writeAsBytesSync((await enc.fileOf(a1)).readAsBytesSync());
      expect(await enc.verify(a2), isFalse);
    });

    test('encryptPending cifra comprobantes antiguos en claro', () async {
      final p = await pending();
      final old = await attachments.add(
        paymentId: p.id,
        source: image('old.jpg', [9, 8, 7]),
      ); // repositorio sin cifrado = dato heredado
      expect(old.encrypted, isFalse);

      expect(await enc.encryptPending(), 1);
      expect(await enc.encryptPending(), 0);
      final after = await (db.select(
        db.attachments,
      )..where((x) => x.id.equals(old.id))).getSingle();
      expect(after.encrypted, isTrue);
      expect(
        AeadCipher.looksEncrypted(
          await (await enc.fileOf(after)).readAsBytes(),
        ),
        isTrue,
      );
      expect(await enc.readBytes(after), [9, 8, 7]);
      expect(await enc.verify(after), isTrue);
    });
  });
}
