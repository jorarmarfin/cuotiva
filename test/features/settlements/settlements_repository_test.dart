import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/payments/domain/payment_errors.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/settlements/data/settlements_repository.dart';
import 'package:cuotiva/features/settlements/domain/settlement_errors.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PaymentsRepository payments;
  late SettlementsRepository settlements;
  late Receivable r;
  late Collection third;
  late Collection own;

  DateTime clock() => DateTime(2026, 11, 17, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    payments = PaymentsRepository(db, audit, uuid, clock);
    settlements = SettlementsRepository(db, audit, uuid, clock);
    final receivables = ReceivablesRepository(
      db,
      audit,
      uuid,
      clock,
      collected: payments.confirmedTotal,
    );
    final space = await SpacesRepository(
      db,
      audit,
      uuid,
      clock,
    ).create(name: 'Capilla', color: 1);
    final contact = await ContactsRepository(
      db,
      audit,
      uuid,
      clock,
    ).create(displayName: 'Rosa');
    final cols = CollectionsRepository(db, audit, uuid, clock);
    third = await cols.create(
      spaceId: space.id,
      title: 'Pasajes',
      fundsOwnership: 'third_party',
    );
    own = await cols.create(spaceId: space.id, title: 'Buzos');
    r = await receivables.create(
      collectionId: third.id,
      contactId: contact.id,
      principal: Money.parse('800'),
    );
    await payments.register(receivableId: r.id, amount: Money.parse('600'));
    // Pendiente de verificación: no cuenta como recaudado.
    await payments.register(
      receivableId: r.id,
      amount: Money.parse('100'),
      confirmNow: false,
    );
  });
  tearDown(() => db.close());

  test('por entregar = recaudado confirmado − entregas confirmadas', () async {
    var s = await settlements.summaryOf(third.id);
    expect(s.collectedMinor, 60000);
    expect(s.toDeliverMinor, 60000);
    await settlements.register(
      collectionId: third.id,
      amount: Money.parse('500'),
      recipientName: 'Padre Juan',
    );
    s = await settlements.summaryOf(third.id);
    expect(s.deliveredMinor, 50000);
    expect(s.toDeliverMinor, 10000);
  });

  test('la rendición no altera la deuda del participante', () async {
    final before = await payments.balanceOf(r.id);
    await settlements.register(
      collectionId: third.id,
      amount: Money.parse('500'),
    );
    final after = await payments.balanceOf(r.id);
    expect(after.balanceMinor, before.balanceMinor);
    expect(after.confirmedMinor, before.confirmedMinor);
    expect(after.status, before.status);
  });

  test('bloquea entregas mayores a lo recaudado', () async {
    await settlements.register(
      collectionId: third.id,
      amount: Money.parse('500'),
    );
    expect(
      () => settlements.register(
        collectionId: third.id,
        amount: Money.parse('100.01'),
      ),
      throwsA(isA<SettlementException>()),
    );
    // El pago por verificar tampoco habilita entregar más.
    expect(
      () => settlements.register(
        collectionId: third.id,
        amount: Money.parse('150'),
      ),
      throwsA(isA<SettlementException>()),
    );
  });

  test('solo cobros de terceros e importes positivos', () async {
    expect(
      () =>
          settlements.register(collectionId: own.id, amount: Money.parse('10')),
      throwsA(isA<SettlementException>()),
    );
    expect(
      () => settlements.register(
        collectionId: third.id,
        amount: const Money.minor(0),
      ),
      throwsA(isA<SettlementException>()),
    );
  });

  test('anular exige motivo, libera lo entregado y queda auditado', () async {
    final s = await settlements.register(
      collectionId: third.id,
      amount: Money.parse('500'),
    );
    expect(
      () => settlements.voidSettlement(s.id, reason: '  '),
      throwsA(isA<SettlementException>()),
    );
    await settlements.voidSettlement(s.id, reason: 'Error de monto');
    expect((await settlements.summaryOf(third.id)).toDeliverMinor, 60000);
    expect((await settlements.find(s.id))!.status, 'voided');
    final logs = await (db.select(
      db.auditLogs,
    )..where((l) => l.entityId.equals(s.id))).get();
    expect(logs.map((l) => l.action), containsAll(['register', 'void']));
    expect(
      () => settlements.voidSettlement(s.id, reason: 'otra vez'),
      throwsA(isA<SettlementException>()),
    );
  });

  test('no se anula un pago si dejaría lo entregado sin respaldo', () async {
    await settlements.register(
      collectionId: third.id,
      amount: Money.parse('500'),
    );
    final p = (await db.select(db.payments).get()).firstWhere(
      (x) => x.status == 'confirmed',
    );
    expect(
      () => payments.voidPayment(p.id, reason: 'duplicado'),
      throwsA(isA<PaymentException>()),
    );
  });
}
