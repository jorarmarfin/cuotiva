import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/installments/data/installments_repository.dart';
import 'package:cuotiva/features/installments/domain/installment_planner.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/balances_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late BalancesRepository balances;
  late PaymentsRepository payments;
  late ReceivablesRepository receivables;
  late InstallmentsRepository installments;
  late ContactsRepository contacts;
  late CollectionsRepository collections;
  late SpacesRepository spaces;

  final now = DateTime(2026, 11, 17, 9);
  DateTime clock() => now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    balances = BalancesRepository(db, clock);
    payments = PaymentsRepository(db, audit, uuid, clock);
    receivables = ReceivablesRepository(
      db,
      audit,
      uuid,
      clock,
      collected: payments.confirmedTotal,
    );
    installments = InstallmentsRepository(db, audit, uuid, clock);
    contacts = ContactsRepository(db, audit, uuid, clock);
    collections = CollectionsRepository(db, audit, uuid, clock);
    spaces = SpacesRepository(db, audit, uuid, clock);
  });
  tearDown(() => db.close());

  Future<Receivable> rec(
    Collection c,
    String name,
    String amount, {
    DateTime? dueAt,
  }) async {
    final p = await contacts.create(displayName: name);
    return receivables.create(
      collectionId: c.id,
      contactId: p.id,
      principal: Money.parse(amount),
      dueAt: dueAt,
    );
  }

  test(
    'totales globales y por espacio; excluye cobros archivados y cancelados',
    () async {
      final a = await spaces.create(name: 'Colegio', color: 1);
      final b = await spaces.create(name: 'Negocio', color: 2);
      final k1 = await collections.create(spaceId: a.id, title: 'Trajes');
      final k2 = await collections.create(spaceId: b.id, title: 'Buzos');
      final k3 = await collections.create(spaceId: b.id, title: 'Viejo');
      final r1 = await rec(k1, 'Ana', '150');
      await rec(k1, 'Beto', '150', dueAt: DateTime(2026, 11, 1)); // vencida
      await rec(k2, 'Cris', '120');
      await rec(k3, 'Dani', '999');
      await collections.archive(k3.id);
      final cancelled = await rec(k2, 'Eva', '500');
      await receivables.cancel(cancelled.id);
      await payments.register(receivableId: r1.id, amount: Money.parse('50'));

      final all = await balances.totals();
      expect(all.committedMinor, 42000);
      expect(all.collectedMinor, 5000);
      expect(all.pendingMinor, 37000);
      expect(all.overdueMinor, 15000);
      expect(all.participants, 3);

      final onlyB = await balances.totals(spaceId: b.id);
      expect(onlyB.committedMinor, 12000);
      expect(onlyB.collectedMinor, 0);
    },
  );

  test(
    'próximos vencimientos: vencidas y dentro de 30 días, orden por fecha',
    () async {
      final s = await spaces.create(name: 'N', color: 1);
      final k = await collections.create(spaceId: s.id, title: 'T');
      await rec(k, 'Vencida', '100', dueAt: DateTime(2026, 11, 10));
      await rec(k, 'Hoy', '100', dueAt: DateTime(2026, 11, 17));
      await rec(k, 'En 20 días', '100', dueAt: DateTime(2026, 12, 7));
      await rec(k, 'En 60 días', '100', dueAt: DateTime(2027, 1, 16));
      await rec(k, 'Sin fecha', '100');

      final due = await balances.upcomingDue();
      expect(due.map((d) => d.dueAt.day), [10, 17, 7]);
      expect(due.first.overdue, isTrue);
      expect(due[1].overdue, isFalse, reason: 'vence hoy: aún no vencida');
    },
  );

  test('con plan usa la primera cuota con saldo y su resto', () async {
    final s = await spaces.create(name: 'N', color: 1);
    final k = await collections.create(spaceId: s.id, title: 'T');
    final r = await rec(k, 'Ana', '120');
    await installments.setPlan(
      r.id,
      InstallmentPlanner.even(
        principalMinor: 12000,
        count: 3,
        firstDue: DateTime(2026, 11, 20),
      ),
    ); // 40 + 40 + 40
    await payments.register(
      receivableId: r.id,
      amount: Money.parse('50'),
    ); // cuota 1 paga; cuota 2 con 10

    final due = await balances.upcomingDue(withinDays: 60);
    expect(due, hasLength(1));
    expect(due.single.dueAt, DateTime(2026, 12, 20));
    expect(due.single.remainingMinor, 3000);
  });

  test(
    'pagadas, canceladas y archivadas no aparecen; filtro por espacio',
    () async {
      final s1 = await spaces.create(name: 'A', color: 1);
      final s2 = await spaces.create(name: 'B', color: 1);
      final k1 = await collections.create(spaceId: s1.id, title: 'T1');
      final k2 = await collections.create(spaceId: s2.id, title: 'T2');
      final paid = await rec(k1, 'Pagada', '50', dueAt: DateTime(2026, 11, 5));
      await payments.register(receivableId: paid.id, amount: Money.parse('50'));
      final cancelled = await rec(
        k1,
        'Cancelada',
        '50',
        dueAt: DateTime(2026, 11, 5),
      );
      await receivables.cancel(cancelled.id);
      await rec(k1, 'Activa A', '50', dueAt: DateTime(2026, 11, 6));
      await rec(k2, 'Activa B', '50', dueAt: DateTime(2026, 11, 7));

      expect((await balances.upcomingDue()).length, 2);
      final onlyB = await balances.upcomingDue(spaceId: s2.id);
      expect(onlyB.single.remainingMinor, 5000);
    },
  );

  test('límite de resultados', () async {
    final s = await spaces.create(name: 'N', color: 1);
    final k = await collections.create(spaceId: s.id, title: 'T');
    for (var i = 0; i < 5; i++) {
      await rec(k, 'P$i', '10', dueAt: DateTime(2026, 11, 1 + i));
    }
    expect(await balances.upcomingDue(limit: 3), hasLength(3));
  });
}
