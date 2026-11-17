import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/core/notifications/notification_service.dart';
import 'package:cuotiva/core/notifications/reminder_planner.dart';
import 'package:cuotiva/core/notifications/reminder_scheduler.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/installments/data/installments_repository.dart';
import 'package:cuotiva/features/installments/domain/installment_planner.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/settings/data/reminders_repository.dart';
import 'package:cuotiva/features/settings/data/settings_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class _Sink implements ReminderSink {
  List<ReminderSpec> last = [];
  bool? hide;
  int calls = 0;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> replaceAll(
    List<ReminderSpec> r, {
    required bool hideContent,
  }) async {
    last = r;
    hide = hideContent;
    calls++;
  }
}

void main() {
  late AppDatabase db;
  late _Sink sink;
  late ReminderScheduler scheduler;
  late SettingsRepository settings;
  late PaymentsRepository payments;
  late ReceivablesRepository receivables;
  late InstallmentsRepository installments;
  late Receivable r;

  final now = DateTime(2026, 11, 17, 10);
  DateTime clock() => now;

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
    installments = InstallmentsRepository(db, audit, uuid, clock);
    settings = SettingsRepository(db);
    sink = _Sink();
    scheduler = ReminderScheduler(
      settings,
      RemindersRepository(db),
      sink,
      clock,
    );
    final space = await SpacesRepository(
      db,
      audit,
      uuid,
      clock,
    ).create(name: 'N', color: 1);
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
    r = await receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('120'),
      dueAt: DateTime(2026, 11, 30),
    );
  });
  tearDown(() => db.close());

  test('desactivado: no programa nada (y limpia lo anterior)', () async {
    expect(await scheduler.reschedule(), 0);
    expect(sink.calls, 1);
    expect(sink.last, isEmpty);
  });

  test('obligación sin plan con vencimiento y saldo', () async {
    await settings.saveReminderSettings(const ReminderSettings(enabled: true));
    expect(await scheduler.reschedule(), 3);
    expect(sink.last.first.body, contains('Rosa'));
    expect(sink.last.first.body, contains('S/ 120.00'));
    expect(sink.hide, isTrue);
  });

  test('al pagar todo, desaparecen los recordatorios', () async {
    await settings.saveReminderSettings(const ReminderSettings(enabled: true));
    await payments.register(receivableId: r.id, amount: Money.parse('120'));
    expect(await scheduler.reschedule(), 0);
  });

  test('un abono parcial reduce el importe del aviso', () async {
    await settings.saveReminderSettings(const ReminderSettings(enabled: true));
    await payments.register(receivableId: r.id, amount: Money.parse('20'));
    await scheduler.reschedule();
    expect(sink.last.first.body, contains('S/ 100.00'));
  });

  test('con plan de cuotas: una serie por cuota impaga', () async {
    await settings.saveReminderSettings(const ReminderSettings(enabled: true));
    await installments.setPlan(
      r.id,
      InstallmentPlanner.even(
        principalMinor: 12000,
        count: 3,
        firstDue: DateTime(2026, 12, 10),
      ),
    );
    await payments.register(receivableId: r.id, amount: Money.parse('40'));
    // Cuota 1 pagada → quedan 2 cuotas × 3 avisos.
    expect(await scheduler.reschedule(), 6);
  });

  test('obligación cancelada o cobro archivado no avisa', () async {
    await settings.saveReminderSettings(const ReminderSettings(enabled: true));
    await receivables.cancel(r.id);
    expect(await scheduler.reschedule(), 0);
  });

  test('watchChanges emite al registrar un pago', () async {
    final repo = RemindersRepository(db);
    final first = repo.watchChanges().first;
    await first;
    final next = repo.watchChanges().skip(1).first;
    await payments.register(receivableId: r.id, amount: Money.parse('10'));
    await next.timeout(const Duration(seconds: 2));
  });
}
