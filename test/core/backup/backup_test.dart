import 'dart:io';
import 'dart:typed_data';

import 'package:cuotiva/core/backup/backup_envelope.dart';
import 'package:cuotiva/core/backup/backup_service.dart';
import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/database/encrypted_database.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/core/security/crypto_service.dart';
import 'package:cuotiva/core/security/db_key_service.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/attachments_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _pass = 'frase-de-prueba-123';

/// Un «dispositivo»: carpeta, base SQLCipher y claves propias.
class _Device {
  _Device(String name, this.keyHex)
    : root = Directory.systemTemp.createTempSync('cuotiva_$name') {
    paths = BackupPaths(
      dbFile: File(p.join(root.path, 'docs', 'cuotiva.sqlite')),
      attachmentsRoot: Directory(p.join(root.path, 'support')),
      workDir: Directory(p.join(root.path, 'docs')),
    );
  }

  final Directory root;
  final String keyHex;
  late final BackupPaths paths;
  late AppDatabase db;
  late AttachmentsRepository attachments;
  late BackupService backup;
  late final cipher = AeadCipher(hexToBytes(keyHex));
  static DateTime clock() => DateTime(2026, 11, 17, 10);

  void open() {
    db = AppDatabase(
      openEncrypted(() async => paths.dbFile, () async => keyHex),
    );
    const uuid = Uuid();
    attachments = AttachmentsRepository(
      db,
      AuditService(db, uuid, clock),
      uuid,
      clock,
      () async => paths.attachmentsRoot,
      () async => cipher,
    );
    backup = BackupService(
      paths: paths,
      attachments: attachments,
      dbHexKey: () async => keyHex,
      attachmentCipher: () async => cipher,
      schemaVersion: db.schemaVersion,
      clock: clock,
      useIsolate: false,
      iterations: 1000,
    );
  }

  Future<void> close() => db.close();
}

void main() {
  // Dos «dispositivos» simulados en el mismo proceso.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Device a;
  late _Device b;
  final photo = List<int>.generate(300, (i) => (i * 7) % 256);

  Future<void> seed(_Device d) async {
    const uuid = Uuid();
    final audit = AuditService(d.db, uuid, _Device.clock);
    final payments = PaymentsRepository(d.db, audit, uuid, _Device.clock);
    final space = await SpacesRepository(
      d.db,
      audit,
      uuid,
      _Device.clock,
    ).create(name: 'Negocio', color: 1);
    final c = await ContactsRepository(
      d.db,
      audit,
      uuid,
      _Device.clock,
    ).create(displayName: 'Rosa');
    final col = await CollectionsRepository(
      d.db,
      audit,
      uuid,
      _Device.clock,
    ).create(spaceId: space.id, title: 'Buzos');
    final r =
        await ReceivablesRepository(
          d.db,
          audit,
          uuid,
          _Device.clock,
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
    final f = File(p.join(d.root.path, 'foto.jpg'))..writeAsBytesSync(photo);
    await d.attachments.add(paymentId: pay.id, source: f);
  }

  setUp(() async {
    a = _Device('a', 'aa' * 32);
    b = _Device('b', 'bb' * 32);
    a.open();
    b.open();
    await seed(a);
  });
  tearDown(() async {
    await a.close();
    await b.close();
    a.root.deleteSync(recursive: true);
    b.root.deleteSync(recursive: true);
  });

  test('sobre: ida y vuelta, frase errónea y alteración', () async {
    final data = Uint8List.fromList(List.generate(500, (i) => i % 251));
    final sealed = await BackupEnvelope.seal(
      data,
      _pass,
      iterations: 1000,
      useIsolate: false,
    );
    expect(await BackupEnvelope.open(sealed, _pass, useIsolate: false), data);

    await expectLater(
      BackupEnvelope.open(sealed, 'otra-frase-distinta', useIsolate: false),
      throwsA(isA<BackupException>()),
    );
    for (final i in [2, 5, 12, 30, sealed.length - 1]) {
      final bad = Uint8List.fromList(sealed)..[i] ^= 1;
      await expectLater(
        BackupEnvelope.open(bad, _pass, useIsolate: false),
        throwsA(isA<BackupException>()),
        reason: 'byte $i',
      );
    }
    await expectLater(
      BackupEnvelope.open(Uint8List(100), _pass, useIsolate: false),
      throwsA(isA<BackupException>()),
    );
  });

  test('frase mínima y generador', () {
    expect(
      () => BackupEnvelope.checkPassphrase('corta'),
      throwsA(isA<BackupException>()),
    );
    final g = BackupEnvelope.generatePassphrase();
    expect(g, matches(RegExp(r'^([A-Z2-9]{5}-){4}[A-Z2-9]{5}$')));
    expect(BackupEnvelope.generatePassphrase(), isNot(g));
  });

  test('el respaldo no contiene texto plano de los datos', () async {
    final bytes = await a.backup.create(_pass, a.db);
    final s = String.fromCharCodes(bytes);
    expect(s, isNot(contains('Rosa')));
    expect(s, isNot(contains('SQLite format')));
  });

  test(
    '§12.11 respaldar → restaurar en otro dispositivo: conteos y hashes',
    () async {
      final bytes = await a.backup.create(_pass, a.db);

      final summary = await b.backup.stageRestore(bytes, _pass);
      expect(summary.counts['spaces'], 1);
      expect(summary.counts['payments'], 1);
      expect(summary.counts['attachments'], 1);
      // Aún no se tocó nada del dispositivo B.
      expect(await b.db.select(b.db.spaces).get(), isEmpty);
      expect(await b.backup.hasPendingRestore, isTrue);

      await b.close();
      expect(await b.backup.applyPendingRestore(), isTrue);
      b.open();

      for (final t in BackupService.tables) {
        final ca =
            (await a.db.customSelect('SELECT count(*) c FROM $t').getSingle())
                .read<int>('c');
        final cb =
            (await b.db.customSelect('SELECT count(*) c FROM $t').getSingle())
                .read<int>('c');
        expect(cb, ca, reason: t);
      }
      final att = (await b.db.select(b.db.attachments).get()).single;
      expect(att.encrypted, isTrue);
      expect(await b.attachments.readBytes(att), photo);
      expect(await b.attachments.verify(att), isTrue);
      // En disco va cifrado con la clave de B, no la de A.
      final onDisk = await (await b.attachments.fileOf(att)).readAsBytes();
      expect(AeadCipher.looksEncrypted(onDisk), isTrue);
      expect(onDisk, isNot(photo));
      expect(await isPlainSqlite(b.paths.dbFile), isFalse);
      expect(b.paths.staging.existsSync(), isFalse);
    },
  );

  test('frase incorrecta o archivo alterado: no cambia nada', () async {
    final bytes = await a.backup.create(_pass, a.db);
    await expectLater(
      b.backup.stageRestore(bytes, 'frase-incorrecta-999'),
      throwsA(isA<BackupException>()),
    );
    final bad = Uint8List.fromList(bytes)..[bytes.length - 20] ^= 1;
    await expectLater(
      b.backup.stageRestore(bad, _pass),
      throwsA(isA<BackupException>()),
    );
    expect(await b.backup.hasPendingRestore, isFalse);
  });

  test('respaldo de una versión de esquema más nueva se rechaza', () async {
    final bytes = await a.backup.create(_pass, a.db);
    final older = BackupService(
      paths: b.paths,
      attachments: b.attachments,
      dbHexKey: () async => b.keyHex,
      attachmentCipher: () async => b.cipher,
      schemaVersion: a.db.schemaVersion - 1,
      clock: _Device.clock,
      useIsolate: false,
    );
    await expectLater(
      older.stageRestore(bytes, _pass),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'msg',
          contains('más nueva'),
        ),
      ),
    );
  });

  test('restaurar sobre datos existentes conserva una copia previa', () async {
    await seed(b); // B ya tiene sus propios datos
    final bytes = await a.backup.create(_pass, a.db);
    await b.backup.stageRestore(bytes, _pass);
    await b.close();
    await b.backup.applyPendingRestore();
    expect(
      File(p.join(b.paths.previous.path, 'cuotiva.sqlite')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(b.paths.previous.path, 'attachments')).existsSync(),
      isTrue,
    );
    b.open();
    expect((await b.db.select(b.db.spaces).get()), hasLength(1));
  });

  test('si el cambio falla se revierte a los datos anteriores', () async {
    await seed(b);
    final bytes = await a.backup.create(_pass, a.db);
    await b.backup.stageRestore(bytes, _pass);
    // Sabotaje: el staging pierde su carpeta de comprobantes → falla al mover.
    Directory(p.join(b.paths.staging.path, 'attachments'))
        .deleteSync(recursive: true);
    await b.close();
    await expectLater(b.backup.applyPendingRestore(), throwsA(anything));
    b.open();
    expect(await b.db.select(b.db.spaces).get(), hasLength(1));
    final att = (await b.db.select(b.db.attachments).get()).single;
    expect(await b.attachments.verify(att), isTrue);
  });

  test('staging sin marcador (cierre a medias) se descarta', () async {
    Directory(p.join(b.paths.staging.path, 'attachments'))
        .createSync(recursive: true);
    expect(await b.backup.applyPendingRestore(), isFalse);
    expect(b.paths.staging.existsSync(), isFalse);
  });
}
