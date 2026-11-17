import 'dart:io';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/attachments_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/balances_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Flujos de aceptación de CUOTIVA_SPEC §12 ejecutados contra la capa de datos real.
class _World {
  _World(AppDatabase database, this.attachmentsDir) : db = database {
    audit = AuditService(db, uuid, clock);
    spaces = SpacesRepository(db, audit, uuid, clock);
    contacts = ContactsRepository(db, audit, uuid, clock);
    collections = CollectionsRepository(db, audit, uuid, clock);
    payments = PaymentsRepository(db, audit, uuid, clock);
    receivables = ReceivablesRepository(
      db,
      audit,
      uuid,
      clock,
      collected: payments.confirmedTotal,
    );
    balances = BalancesRepository(db, clock);
    attachments = AttachmentsRepository(
      db,
      audit,
      uuid,
      clock,
      () async => attachmentsDir,
    );
  }

  static const uuid = Uuid();
  static DateTime clock() => DateTime(2026, 11, 17, 10);

  final AppDatabase db;
  final Directory attachmentsDir;
  late final AuditService audit;
  late final SpacesRepository spaces;
  late final ContactsRepository contacts;
  late final CollectionsRepository collections;
  late final PaymentsRepository payments;
  late final ReceivablesRepository receivables;
  late final BalancesRepository balances;
  late final AttachmentsRepository attachments;
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('cuotiva_it_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('§12.1-5: venta a crédito S/120 con abonos 30 → 40 pendiente → confirmar → 50', () async {
    final w = _World(AppDatabase(NativeDatabase.memory()), tmp);
    addTearDown(w.db.close);

    final space = await w.spaces.create(name: 'Negocio', color: 0xFF34D399);
    final client = await w.contacts.create(
      displayName: 'Rosa Quispe',
      phone: '987 654 321',
    );
    final sale = await w.collections.create(
      spaceId: space.id,
      title: 'Buzo',
      kind: 'credit_sale',
    );
    final r = await w.receivables.create(
      collectionId: sale.id,
      contactId: client.id,
      principal: Money.parse('120'),
    );

    await w.payments.register(receivableId: r.id, amount: Money.parse('30'));
    expect((await w.balances.forReceivable(r.id))!.balanceMinor, 9000); // 2

    final p40 = await w.payments.register(
      receivableId: r.id,
      amount: Money.parse('40'),
      method: 'yape',
      confirmNow: false,
    );
    final img = File('${tmp.path}/yape.jpg')..writeAsBytesSync([1, 2, 3]);
    await w.attachments.add(paymentId: p40.id, source: img);
    expect(
      (await w.balances.forReceivable(r.id))!.balanceMinor,
      9000,
      reason: 'adjunto ≠ pago confirmado',
    ); // 3

    await w.payments.confirm(p40.id);
    expect((await w.balances.forReceivable(r.id))!.balanceMinor, 5000); // 4

    await w.payments.register(receivableId: r.id, amount: Money.parse('50'));
    final end = (await w.balances.forReceivable(r.id))!;
    expect(end.status, ReceivableStatus.paid); // 5
    expect(end.balanceMinor, 0);
    expect(end.confirmedMinor, 12000);

    final confirmed = (await w.db.select(w.db.payments).get()).where(
      (p) => p.status == 'confirmed',
    );
    expect(
      confirmed,
      hasLength(3),
      reason: 'los tres movimientos figurarían en el PDF',
    );
  });

  test(
    '§12.8: campaña de 20 participantes, balance global = suma de obligaciones',
    () async {
      final w = _World(AppDatabase(NativeDatabase.memory()), tmp);
      addTearDown(w.db.close);

      final space = await w.spaces.create(name: 'Colegio', color: 0xFF2563EB);
      final col = await w.collections.create(
        spaceId: space.id,
        title: 'Trajes 2027',
        kind: 'fundraising',
      );
      final ids = [
        for (var i = 1; i <= 20; i++)
          (await w.contacts.create(displayName: 'Padre $i')).id,
      ];
      final created = await w.receivables.bulkCreate(
        collectionId: col.id,
        contactIds: ids,
        principal: Money.parse('150'),
      );

      // 5 pagan completo, 3 pagan la mitad, 1 con pago pendiente (no cuenta)
      for (final r in created.take(5)) {
        await w.payments.register(
          receivableId: r.id,
          amount: Money.parse('150'),
        );
      }
      for (final r in created.skip(5).take(3)) {
        await w.payments.register(
          receivableId: r.id,
          amount: Money.parse('75'),
        );
      }
      await w.payments.register(
        receivableId: created[8].id,
        amount: Money.parse('100'),
        method: 'plin',
        confirmNow: false,
      );

      final t = await w.balances.totals();
      expect(t.participants, 20);
      expect(t.committedMinor, 20 * 15000);
      expect(t.collectedMinor, 5 * 15000 + 3 * 7500);
      expect(
        t.pendingMinor,
        t.committedMinor - t.collectedMinor,
        reason: 'por cobrar + recaudado = comprometido',
      );
      expect(t.progress, closeTo((5 * 15000 + 3 * 7500) / 300000, 1e-9));
    },
  );

  test('§12.10: al cerrar y reabrir se conservan datos e imágenes', () async {
    final file = File('${tmp.path}/cuotiva.sqlite');
    final attDir = Directory('${tmp.path}/private')..createSync();
    late String paymentId;
    late String receivableId;

    var w = _World(AppDatabase(NativeDatabase(file)), attDir);
    final space = await w.spaces.create(name: 'Familia', color: 1);
    final c = await w.contacts.create(displayName: 'María');
    final col = await w.collections.create(
      spaceId: space.id,
      title: 'Préstamo a María',
      kind: 'loan',
    );
    final r = await w.receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('500'),
    );
    receivableId = r.id;
    final p = await w.payments.register(
      receivableId: r.id,
      amount: Money.parse('100'),
      method: 'transfer',
      confirmNow: false,
    );
    paymentId = p.id;
    await w.attachments.add(
      paymentId: p.id,
      source: File('${tmp.path}/x.png')..writeAsBytesSync([9, 8, 7, 6]),
    );
    await w.db.close();

    // "Reinicio de la app": nueva instancia sobre el mismo archivo.
    w = _World(AppDatabase(NativeDatabase(file)), attDir);
    addTearDown(w.db.close);
    expect((await w.receivables.find(receivableId))!.principalMinor, 50000);
    final pay = (await w.payments.find(paymentId))!;
    expect(pay.status, 'pending_verification');
    final atts = await w.db.select(w.db.attachments).get();
    expect(atts, hasLength(1));
    expect(
      await w.attachments.verify(atts.single),
      isTrue,
      reason: 'imagen intacta (checksum)',
    );
    expect((await w.db.select(w.db.auditLogs).get()), isNotEmpty);
  });

  test('sin operaciones financieras sin auditoría', () async {
    final w = _World(AppDatabase(NativeDatabase.memory()), tmp);
    addTearDown(w.db.close);
    final space = await w.spaces.create(name: 'N', color: 1);
    final c = await w.contacts.create(displayName: 'Ana');
    final col = await w.collections.create(spaceId: space.id, title: 'T');
    final r = await w.receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('100'),
    );
    final p = await w.payments.register(
      receivableId: r.id,
      amount: Money.parse('40'),
      confirmNow: false,
    );
    await w.payments.confirm(p.id);
    await w.payments.voidPayment(p.id, reason: 'prueba');
    await w.receivables.updatePrincipal(r.id, Money.parse('90'));

    final logs = await w.db.select(w.db.auditLogs).get();
    bool has(String type, String id, String action) => logs.any(
      (l) => l.entityType == type && l.entityId == id && l.action == action,
    );
    expect(has('payment', p.id, 'register'), isTrue);
    expect(has('payment', p.id, 'confirm'), isTrue);
    expect(has('payment', p.id, 'void'), isTrue);
    expect(has('receivable', r.id, 'create'), isTrue);
    expect(has('receivable', r.id, 'update_principal'), isTrue);
    // Todo cambio queda con sello de tiempo y entidad.
    expect(
      logs.every((l) => l.entityId.isNotEmpty && l.action.isNotEmpty),
      isTrue,
    );
  });
}
