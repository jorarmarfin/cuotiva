import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/installments/data/installments_repository.dart';
import 'package:cuotiva/features/installments/domain/installment_planner.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/payments/domain/payment_errors.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/receivables/domain/receivable_errors.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late InstallmentsRepository installments;
  late PaymentsRepository payments;
  late ReceivablesRepository receivables;
  late Receivable r;

  var now = DateTime(2026, 11, 17);
  DateTime clock() => now;

  setUp(() async {
    now = DateTime(2026, 11, 17);
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    installments = InstallmentsRepository(db, audit, uuid, clock);
    payments = PaymentsRepository(db, audit, uuid, clock);
    receivables = ReceivablesRepository(
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
    r = await receivables.create(
      collectionId: col.id,
      contactId: contact.id,
      principal: Money.parse('120'),
    );
  });
  tearDown(() => db.close());

  List<InstallmentDraft> three() => InstallmentPlanner.even(
    principalMinor: 12000,
    count: 3,
    firstDue: DateTime(2026, 12, 1),
  ); // 40 + 40 + 40

  Future<void> pay(
    String amount, {
    bool confirm = true,
    String? installmentId,
  }) => payments.register(
    receivableId: r.id,
    amount: Money.parse(amount),
    confirmNow: confirm,
    installmentId: installmentId,
  );

  test('guarda el plan ordenado por fecha con sequence 1..n', () async {
    final drafts = three().reversed.toList();
    await installments.setPlan(r.id, drafts);
    final list = await installments.list(r.id);
    expect(list.map((i) => i.sequence), [1, 2, 3]);
    expect(list.first.dueAt, DateTime(2026, 12, 1));
  });

  test('rechaza plan cuya suma no coincide; no toca el plan previo', () async {
    await installments.setPlan(r.id, three());
    await expectLater(
      installments.setPlan(r.id, [
        InstallmentDraft(dueAt: DateTime(2027, 1, 1), amountMinor: 100),
      ]),
      throwsA(isA<PlanException>()),
    );
    expect(await installments.list(r.id), hasLength(3));
  });

  test('pagos confirmados se asignan a la cuota más antigua primero', () async {
    await installments.setPlan(r.id, three());
    await pay('50'); // cuota 1 completa (40) + 10 de la cuota 2
    final plan = await installments.plan(r.id);
    expect(plan.map((v) => v.paidMinor), [4000, 1000, 0]);
    expect(plan.map((v) => v.status), [
      InstallmentStatus.paid,
      InstallmentStatus.partial,
      InstallmentStatus.pending,
    ]);
  });

  test('abono dirigido a una cuota la paga aunque haya anteriores', () async {
    await installments.setPlan(r.id, three());
    final c = await installments.list(r.id);
    await pay('40', installmentId: c[2].id);
    expect((await installments.plan(r.id)).map((v) => v.paidMinor), [
      0,
      0,
      4000,
    ]);
  });

  test(
    'exceso sobre la cuota elegida pasa a la más antigua con saldo',
    () async {
      await installments.setPlan(r.id, three());
      final c = await installments.list(r.id);
      await pay('55', installmentId: c[1].id); // 40 a la 2 + 15 a la 1
      expect((await installments.plan(r.id)).map((v) => v.paidMinor), [
        1500,
        4000,
        0,
      ]);
    },
  );

  test('abono parcial dirigido y otro automático conviven', () async {
    await installments.setPlan(r.id, three());
    final c = await installments.list(r.id);
    await pay('10', installmentId: c[1].id);
    await pay('40');
    expect((await installments.plan(r.id)).map((v) => v.paidMinor), [
      4000,
      1000,
      0,
    ]);
  });

  test('anular el abono dirigido libera la cuota', () async {
    await installments.setPlan(r.id, three());
    final c = await installments.list(r.id);
    await pay('40', installmentId: c[2].id);
    final p = (await db.select(db.payments).get()).single;
    await payments.voidPayment(p.id, reason: 'error');
    expect(
      (await installments.plan(r.id)).every((v) => v.paidMinor == 0),
      isTrue,
    );
  });

  test('rechaza una cuota de otra obligación', () async {
    await installments.setPlan(r.id, three());
    await expectLater(
      pay('10', installmentId: 'no-existe'),
      throwsA(isA<PaymentException>()),
    );
  });

  test('reemplazar el plan limpia el destino de los abonos', () async {
    await installments.setPlan(r.id, three());
    final c = await installments.list(r.id);
    await pay('40', installmentId: c[2].id);
    await installments.setPlan(r.id, three());
    final p = (await db.select(db.payments).get()).single;
    expect(p.installmentId, isNull);
    expect((await installments.plan(r.id)).map((v) => v.paidMinor), [
      4000,
      0,
      0,
    ]);
  });

  test('pago pendiente no se asigna hasta confirmarse', () async {
    await installments.setPlan(r.id, three());
    await pay('40', confirm: false);
    expect(
      (await installments.plan(r.id)).every((v) => v.paidMinor == 0),
      isTrue,
    );
    final p = (await db.select(db.payments).get()).single;
    await payments.confirm(p.id);
    expect(
      (await installments.plan(r.id)).first.status,
      InstallmentStatus.paid,
    );
  });

  test('anular un pago reasigna: la cuota vuelve a quedar pendiente', () async {
    await installments.setPlan(r.id, three());
    await pay('40');
    await pay('40');
    final first = (await db.select(db.payments).get()).first;
    await payments.voidPayment(first.id, reason: 'error');
    final plan = await installments.plan(r.id);
    expect(plan.map((v) => v.paidMinor), [4000, 0, 0]);
  });

  test('plan posterior a los pagos: reasigna los ya confirmados', () async {
    await pay('70');
    await installments.setPlan(r.id, three());
    expect((await installments.plan(r.id)).map((v) => v.paidMinor), [
      4000,
      3000,
      0,
    ]);
  });

  test('la suma de asignaciones nunca supera el pago ni la cuota', () async {
    await installments.setPlan(r.id, three());
    await pay('30');
    await pay('90');
    final allocs = await db.select(db.paymentAllocations).get();
    final pays = {
      for (final p in await db.select(db.payments).get()) p.id: p.amountMinor,
    };
    final byPayment = <String, int>{};
    for (final a in allocs) {
      byPayment[a.paymentId] = (byPayment[a.paymentId] ?? 0) + a.amountMinor;
    }
    byPayment.forEach((id, sum) => expect(sum, lessThanOrEqualTo(pays[id]!)));
    expect(allocs.fold<int>(0, (s, a) => s + a.amountMinor), 12000);
    expect(
      (await installments.plan(r.id))
          .every((v) => v.status == InstallmentStatus.paid),
      isTrue,
    );
  });

  test('cuota vencida con saldo: overdue', () async {
    await installments.setPlan(r.id, three());
    now = DateTime(2026, 12, 2);
    expect(
      (await installments.plan(r.id)).first.status,
      InstallmentStatus.overdue,
    );
    now = DateTime(2026, 12, 1); // el día límite aún no está vencida
    expect(
      (await installments.plan(r.id)).first.status,
      InstallmentStatus.pending,
    );
  });

  test('con plan no se cambia el importe de la obligación', () async {
    await installments.setPlan(r.id, three());
    await expectLater(
      receivables.updatePrincipal(r.id, Money.parse('150')),
      throwsA(isA<ReceivableException>()),
    );
  });

  test('clearPlan vuelve a modo libre y borra asignaciones', () async {
    await installments.setPlan(r.id, three());
    await pay('40');
    await installments.clearPlan(r.id);
    expect(await installments.list(r.id), isEmpty);
    expect(await db.select(db.paymentAllocations).get(), isEmpty);
    expect(
      await payments.confirmedTotal(r.id),
      4000,
      reason: 'los pagos no se tocan',
    );
  });

  test('cambios de plan quedan auditados', () async {
    await installments.setPlan(r.id, three());
    await installments.clearPlan(r.id);
    final actions = (await db.select(db.auditLogs).get())
        .where((l) => l.entityId == r.id)
        .map((l) => l.action)
        .toList();
    expect(
      actions,
      containsAll(['set_installment_plan', 'clear_installment_plan']),
    );
  });
  test(
    'watchPlan emite el plan nuevo al definirlo (la UI se refresca sola)',
    () async {
      final emissions = <int>[];
      final sub = installments
          .watchPlan(r.id)
          .listen((v) => emissions.add(v.length));
      await pumpEventQueue();
      expect(emissions.last, 0);

      await installments.setPlan(
        r.id,
        InstallmentPlanner.even(
          principalMinor: 12000,
          count: 3,
          firstDue: DateTime(2026, 12, 1),
        ),
      );
      await pumpEventQueue(times: 50);
      expect(emissions.last, 3, reason: 'emisiones: $emissions');

      await installments.clearPlan(r.id);
      await pumpEventQueue(times: 50);
      expect(emissions.last, 0, reason: 'emisiones: $emissions');
      await sub.cancel();
    },
  );
  test(
    'streams con distintas tablas no se pisan entre sí (misma consulta base)',
    () async {
      // Otro stream activo, con tablas distintas, registrado ANTES que el del plan.
      final other = db
          .customSelect('SELECT 1', readsFrom: {db.receivables})
          .watch()
          .listen((_) {});
      final emissions = <int>[];
      final sub = installments
          .watchPlan(r.id)
          .listen((v) => emissions.add(v.length));
      await pumpEventQueue();
      await installments.setPlan(
        r.id,
        InstallmentPlanner.even(
          principalMinor: 12000,
          count: 2,
          firstDue: DateTime(2026, 12, 1),
        ),
      );
      await pumpEventQueue(times: 50);
      expect(emissions.last, 2, reason: 'emisiones: $emissions');
      await sub.cancel();
      await other.cancel();
    },
  );
}
