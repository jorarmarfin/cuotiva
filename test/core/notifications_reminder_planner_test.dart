import 'package:cuotiva/core/notifications/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

String money(int m) => 'S/ ${(m / 100).toStringAsFixed(2)}';

void main() {
  final now = DateTime(2026, 11, 17, 10);
  final item = DueItem(
    key: 'i1',
    person: 'Rosa',
    concept: 'Buzos',
    dueAt: DateTime(2026, 11, 20),
    amountMinor: 5000,
  );
  const on = ReminderSettings(enabled: true);

  test('desactivado no programa nada', () {
    expect(
      ReminderPlanner.plan([item], const ReminderSettings(), now, money),
      isEmpty,
    );
  });

  test('por vencer (1 día antes), hoy y vencida, a la hora configurada', () {
    final r = ReminderPlanner.plan([item], on, now, money);
    expect(r.map((e) => e.kind), [
      ReminderKind.upcoming,
      ReminderKind.dueToday,
      ReminderKind.overdue,
    ]);
    expect(r[0].when, DateTime(2026, 11, 19, 9));
    expect(r[1].when, DateTime(2026, 11, 20, 9));
    expect(r[2].when, DateTime(2026, 11, 21, 9));
    expect(r[0].body, contains('Rosa'));
    expect(r[0].body, contains('S/ 50.00'));
  });

  test('omite recordatorios en el pasado', () {
    final late = DateTime(2026, 11, 20, 9, 30);
    final r = ReminderPlanner.plan([item], on, late, money);
    expect(r.map((e) => e.kind), [ReminderKind.overdue]);
  });

  test('contenido público genérico (sin nombres ni importes)', () {
    for (final r in ReminderPlanner.plan([item], on, now, money)) {
      expect(r.publicBody, isNot(contains('Rosa')));
      expect(r.publicBody, isNot(contains('S/')));
    }
  });

  test('ids estables y distintos por tipo', () {
    final a = ReminderPlanner.plan([item], on, now, money);
    final b = ReminderPlanner.plan([item], on, now, money);
    expect(a.map((e) => e.id), b.map((e) => e.id));
    expect(a.map((e) => e.id).toSet(), hasLength(3));
  });

  test('daysBefore = 0 no genera «por vencer»', () {
    final r = ReminderPlanner.plan(
      [item],
      on.copyWith(daysBefore: 0),
      now,
      money,
    );
    expect(r.map((e) => e.kind), isNot(contains(ReminderKind.upcoming)));
  });

  test('límite de alarmas: se quedan las más próximas', () {
    final many = [
      for (var i = 0; i < 100; i++)
        DueItem(
          key: 'k$i',
          person: 'P$i',
          concept: 'C',
          dueAt: DateTime(2026, 12, 1).add(Duration(days: i)),
          amountMinor: 100,
        ),
    ];
    final r = ReminderPlanner.plan(many, on, now, money);
    expect(r, hasLength(ReminderPlanner.maxReminders));
    expect(r.first.when.isBefore(r.last.when), isTrue);
  });

  test('ajustes: codificación ida y vuelta y valores inválidos', () {
    const s = ReminderSettings(
      enabled: true,
      daysBefore: 3,
      hour: 18,
      hideContent: false,
    );
    final d = ReminderSettings.decode(s.encode());
    expect(d.enabled, isTrue);
    expect(d.daysBefore, 3);
    expect(d.hour, 18);
    expect(d.hideContent, isFalse);
    expect(ReminderSettings.decode('basura').hideContent, isTrue);
    expect(ReminderSettings.decode('1:1:99:1').hour, 23);
  });
}
