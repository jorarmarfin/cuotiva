import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/payments/domain/payment_errors.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/receivables/domain/receivable_errors.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PaymentsRepository payments;
  late ReceivablesRepository receivables;
  late Receivable r;

  DateTime clock() => DateTime(2026, 11, 17, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
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
    ).create(name: 'Negocio', color: 1);
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
    ).create(spaceId: space.id, title: 'Buzos');
    r = await receivables.create(
      collectionId: col.id,
      contactId: contact.id,
      principal: Money.parse('120'),
    );
  });
  tearDown(() => db.close());

  Future<Payment> pay(String amount, {bool confirm = true}) =>
      payments.register(
        receivableId: r.id,
        amount: Money.parse(amount),
        confirmNow: confirm,
      );

  test('flujo §12: 120 → 30 confirmado (90) → 40 pendiente (90) → confirmar (50) → 50 (paid)', () async {
    await pay('30');
    expect((await payments.balanceOf(r.id)).balanceMinor, 9000);

    final p40 = await pay('40', confirm: false);
    var b = await payments.balanceOf(r.id);
    expect(b.balanceMinor, 9000, reason: 'pendiente no descuenta');
    expect(b.pendingVerificationMinor, 4000);

    await payments.confirm(p40.id);
    expect((await payments.balanceOf(r.id)).balanceMinor, 5000);

    await pay('50');
    b = await payments.balanceOf(r.id);
    expect(b.balanceMinor, 0);
    expect(b.status, ReceivableStatus.paid);
  });

  test('rechaza pago mayor al saldo con mensaje claro', () async {
    await pay('100');
    await expectLater(
      pay('30'),
      throwsA(
        isA<PaymentException>().having(
          (e) => e.message,
          'message',
          contains('excede el saldo'),
        ),
      ),
    );
    expect(await db.select(db.payments).get(), hasLength(1));
  });

  test(
    'confirmar revalida el saldo (dos pendientes que juntos exceden)',
    () async {
      final a = await pay('70', confirm: false);
      final b = await pay('70', confirm: false);
      await payments.confirm(a.id);
      await expectLater(
        payments.confirm(b.id),
        throwsA(isA<PaymentException>()),
      );
      expect((await payments.find(b.id))!.status, 'pending_verification');
    },
  );

  test('anular restaura el saldo y deja audit trail', () async {
    final p = await pay('30');
    await payments.voidPayment(p.id, reason: 'Error de digitación');
    expect((await payments.balanceOf(r.id)).balanceMinor, 12000);
    final v = (await payments.find(p.id))!;
    expect(v.status, 'voided');
    expect(v.voidReason, 'Error de digitación');
    expect(v.voidedAt, isNotNull);
    final logs = (await db.select(db.auditLogs).get())
        .where((l) => l.entityId == p.id)
        .map((l) => l.action);
    expect(logs, containsAll(['register', 'void']));
  });

  test('anular exige motivo y solo aplica a confirmados', () async {
    final p = await pay('30');
    await expectLater(
      payments.voidPayment(p.id, reason: '  '),
      throwsA(isA<PaymentException>()),
    );
    final pending = await pay('10', confirm: false);
    await expectLater(
      payments.voidPayment(pending.id, reason: 'x'),
      throwsA(isA<PaymentException>()),
    );
    await payments.voidPayment(p.id, reason: 'x');
    await expectLater(
      payments.voidPayment(p.id, reason: 'otra vez'),
      throwsA(isA<PaymentException>()),
    );
  });

  test(
    'rechazar un pendiente no afecta saldo; no se puede confirmar luego',
    () async {
      final p = await pay('40', confirm: false);
      await payments.reject(p.id, reason: 'Captura no coincide');
      expect((await payments.balanceOf(r.id)).balanceMinor, 12000);
      expect((await payments.find(p.id))!.status, 'rejected');
      await expectLater(
        payments.confirm(p.id),
        throwsA(isA<PaymentException>()),
      );
      await expectLater(
        payments.reject(p.id),
        throwsA(isA<PaymentException>()),
      );
    },
  );

  test('no se confirma dos veces', () async {
    final p = await pay('10', confirm: false);
    await payments.confirm(p.id);
    await expectLater(payments.confirm(p.id), throwsA(isA<PaymentException>()));
  });

  test('validaciones: importe, medio, moneda, obligación cancelada', () async {
    await expectLater(
      payments.register(receivableId: r.id, amount: const Money.zero()),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      payments.register(
        receivableId: r.id,
        amount: Money.parse('1'),
        method: 'bitcoin',
      ),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      payments.register(
        receivableId: r.id,
        amount: const Money.minor(100, currency: 'USD'),
      ),
      throwsA(isA<PaymentException>()),
    );
    await receivables.cancel(r.id);
    await expectLater(pay('10'), throwsA(isA<PaymentException>()));
  });

  test(
    'regla de obligación: no reducir bajo lo cobrado ni cancelar con pagos',
    () async {
      await pay('70');
      await expectLater(
        receivables.updatePrincipal(r.id, Money.parse('50')),
        throwsA(isA<ReceivableException>()),
      );
      await receivables.updatePrincipal(r.id, Money.parse('70'));
      expect((await payments.balanceOf(r.id)).status, ReceivableStatus.paid);
      await expectLater(
        receivables.cancel(r.id),
        throwsA(isA<ReceivableException>()),
      );
    },
  );

  test('todo movimiento financiero queda auditado', () async {
    final p = await pay('30', confirm: false);
    await payments.confirm(p.id);
    await payments.voidPayment(p.id, reason: 'x');
    final actions = (await db.select(db.auditLogs).get())
        .where((l) => l.entityId == p.id)
        .map((l) => l.action)
        .toList();
    expect(actions, ['register', 'confirm', 'void']);
  });

  test('confirmedTotal suma solo confirmados', () async {
    await pay('30');
    await pay('20', confirm: false);
    final v = await pay('10');
    await payments.voidPayment(v.id, reason: 'x');
    expect(await payments.confirmedTotal(r.id), 3000);
  });

  test('el pago pendiente puede registrarse aunque sea > saldo - pendientes (se valida al confirmar)', () async {
    await pay('60', confirm: false);
    await pay('60', confirm: false);
    expect((await db.select(db.payments).get()), hasLength(2));
  });
}
