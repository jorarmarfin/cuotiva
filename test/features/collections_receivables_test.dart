import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/receivables/domain/receivable_errors.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late AuditService audit;
  late SpacesRepository spaces;
  late ContactsRepository contacts;
  late CollectionsRepository collections;
  late ReceivablesRepository receivables;
  var collected = 0;

  DateTime clock() => DateTime(2026, 11, 17);

  setUp(() {
    collected = 0;
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    audit = AuditService(db, uuid, clock);
    spaces = SpacesRepository(db, audit, uuid, clock);
    contacts = ContactsRepository(db, audit, uuid, clock);
    collections = CollectionsRepository(db, audit, uuid, clock);
    receivables = ReceivablesRepository(
      db,
      audit,
      uuid,
      clock,
      collected: (_) async => collected,
    );
  });
  tearDown(() => db.close());

  Future<Collection> newCollection({String title = 'Trajes 2027'}) async {
    final s = await spaces.create(name: 'Colegio', color: 1);
    return collections.create(spaceId: s.id, title: title, kind: 'fundraising');
  }

  test('cobro valida título, tipo y titularidad de fondos', () async {
    final s = await spaces.create(name: 'Colegio', color: 1);
    expect(
      () => collections.create(spaceId: s.id, title: ' '),
      throwsArgumentError,
    );
    expect(
      () => collections.create(spaceId: s.id, title: 'X', kind: 'zzz'),
      throwsArgumentError,
    );
    expect(
      () =>
          collections.create(spaceId: s.id, title: 'X', fundsOwnership: 'otro'),
      throwsArgumentError,
    );
    final c = await collections.create(
      spaceId: s.id,
      title: 'Pasajes',
      fundsOwnership: 'third_party',
    );
    expect(c.fundsOwnership, 'third_party');
  });

  test('listar cobros filtra por espacio y búsqueda', () async {
    final a = await spaces.create(name: 'A', color: 1);
    final b = await spaces.create(name: 'B', color: 1);
    await collections.create(spaceId: a.id, title: 'Trajes');
    await collections.create(spaceId: b.id, title: 'Pasaje');
    expect(await collections.watchActive(spaceId: a.id).first, hasLength(1));
    expect(await collections.watchActive(query: 'pasa').first, hasLength(1));
    expect(await collections.watchActive().first, hasLength(2));
  });

  test('asignación masiva S/ 150 a 20 personas suma S/ 3,000', () async {
    final c = await newCollection();
    final ids = [
      for (var i = 0; i < 20; i++)
        (await contacts.create(displayName: 'Padre $i')).id,
    ];
    final created = await receivables.bulkCreate(
      collectionId: c.id,
      contactIds: ids,
      principal: Money.parse('150'),
    );
    expect(created, hasLength(20));
    final total = created.fold<int>(0, (s, r) => s + r.principalMinor);
    expect(total, 300000);
  });

  test('bulk es atómico: duplicado revierte todo', () async {
    final c = await newCollection();
    final a = await contacts.create(displayName: 'A');
    final b = await contacts.create(displayName: 'B');
    await receivables.create(
      collectionId: c.id,
      contactId: b.id,
      principal: Money.parse('10'),
    );
    await expectLater(
      receivables.bulkCreate(
        collectionId: c.id,
        contactIds: [a.id, b.id],
        principal: Money.parse('150'),
      ),
      throwsA(isA<ReceivableException>()),
    );
    expect(await receivables.watchByCollection(c.id).first, hasLength(1));
  });

  test('bulk con skipExisting omite los ya asignados', () async {
    final c = await newCollection();
    final a = await contacts.create(displayName: 'A');
    final b = await contacts.create(displayName: 'B');
    await receivables.create(
      collectionId: c.id,
      contactId: b.id,
      principal: Money.parse('10'),
    );
    final r = await receivables.bulkCreate(
      collectionId: c.id,
      contactIds: [a.id, b.id],
      principal: Money.parse('150'),
      skipExisting: true,
    );
    expect(r.map((e) => e.contactId), [a.id]);
  });

  test('mismo contacto en cobros de distintos espacios', () async {
    final k1 = await newCollection();
    final s2 = await spaces.create(name: 'Familia', color: 2);
    final k2 = await collections.create(
      spaceId: s2.id,
      title: 'Préstamo',
      kind: 'loan',
    );
    final p = await contacts.create(displayName: 'María');
    await receivables.create(
      collectionId: k1.id,
      contactId: p.id,
      principal: Money.parse('150'),
    );
    await receivables.create(
      collectionId: k2.id,
      contactId: p.id,
      principal: Money.parse('500'),
    );
    expect(await receivables.watchByContact(p.id).first, hasLength(2));
  });

  test('importe debe ser positivo', () async {
    final c = await newCollection();
    final p = await contacts.create(displayName: 'María');
    expect(
      receivables.create(
        collectionId: c.id,
        contactId: p.id,
        principal: const Money.zero(),
      ),
      throwsA(isA<ReceivableException>()),
    );
  });

  test('no reducir importe por debajo de lo cobrado', () async {
    final c = await newCollection();
    final p = await contacts.create(displayName: 'María');
    final r = await receivables.create(
      collectionId: c.id,
      contactId: p.id,
      principal: Money.parse('120'),
    );
    collected = 7000;
    await expectLater(
      receivables.updatePrincipal(r.id, Money.parse('50')),
      throwsA(isA<ReceivableException>()),
    );
    await receivables.updatePrincipal(r.id, Money.parse('70'));
    expect((await receivables.find(r.id))!.principalMinor, 7000);
    final logs = await db.select(db.auditLogs).get();
    expect(logs.where((l) => l.action == 'update_principal'), hasLength(1));
  });

  test('no se cancela una obligación con pagos confirmados', () async {
    final c = await newCollection();
    final p = await contacts.create(displayName: 'María');
    final r = await receivables.create(
      collectionId: c.id,
      contactId: p.id,
      principal: Money.parse('10'),
    );
    collected = 100;
    await expectLater(
      receivables.cancel(r.id),
      throwsA(isA<ReceivableException>()),
    );
    collected = 0;
    await receivables.cancel(r.id);
    expect((await receivables.find(r.id))!.cancelledAt, isNotNull);
  });
}
