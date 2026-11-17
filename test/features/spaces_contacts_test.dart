import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late SpacesRepository spaces;
  late ContactsRepository contacts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    DateTime clock() => DateTime(2026, 11, 17);
    final audit = AuditService(db, uuid, clock);
    spaces = SpacesRepository(db, audit, uuid, clock);
    contacts = ContactsRepository(db, audit, uuid, clock);
  });
  tearDown(() => db.close());

  test('crear espacio audita y valida nombre', () async {
    final s = await spaces.create(name: '  Negocio ', color: 0xFF6D28D9);
    expect(s.name, 'Negocio');
    final logs = await db.select(db.auditLogs).get();
    expect(logs.single.action, 'create');
    expect(logs.single.entityId, s.id);
    expect(() => spaces.create(name: '  ', color: 1), throwsArgumentError);
  });

  test('archivar espacio lo oculta de la lista activa', () async {
    final s = await spaces.create(name: 'Familia', color: 1);
    await spaces.archive(s.id);
    expect(await spaces.watchActive().first, isEmpty);
    expect((await spaces.find(s.id))!.archivedAt, isNotNull);
  });

  test('update de espacio guarda valores viejos y nuevos', () async {
    final s = await spaces.create(name: 'A', color: 1);
    await spaces.update(s.id, name: 'B');
    final log = (await db.select(db.auditLogs).get()).firstWhere(
      (l) => l.action == 'update',
    );
    expect(log.oldValuesJson, contains('"A"'));
    expect(log.newValuesJson, contains('"B"'));
  });

  test('contacto normaliza teléfono y busca por nombre', () async {
    final c = await contacts.create(
      displayName: 'Rosa Pérez',
      phone: '+51 987-654 321',
    );
    expect(c.phone, '+51987654321');
    await contacts.create(displayName: 'Juan');
    expect((await contacts.watchActive(query: 'rosa').first).map((e) => e.id), [
      c.id,
    ]);
    expect(await contacts.watchActive().first, hasLength(2));
  });

  test('contacto sin nombre rechazado; teléfono vacío es null', () async {
    expect(() => contacts.create(displayName: ' '), throwsArgumentError);
    final c = await contacts.create(displayName: 'X', phone: '  ');
    expect(c.phone, isNull);
  });
}
