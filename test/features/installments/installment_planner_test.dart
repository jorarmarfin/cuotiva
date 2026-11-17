import 'package:cuotiva/features/installments/domain/installment_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('even', () {
    test('S/ 100 en 3 cuotas: suma exacta (33.34 + 33.33 + 33.33)', () {
      final plan = InstallmentPlanner.even(
        principalMinor: 10000,
        count: 3,
        firstDue: DateTime(2026, 12, 1),
      );
      expect(plan.map((d) => d.amountMinor), [3334, 3333, 3333]);
      expect(plan.fold<int>(0, (s, d) => s + d.amountMinor), 10000);
    });

    test('fechas mensuales con ajuste de fin de mes', () {
      final plan = InstallmentPlanner.even(
        principalMinor: 9000,
        count: 4,
        firstDue: DateTime(2027, 1, 31),
      );
      expect(plan.map((d) => d.dueAt), [
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('año bisiesto y cambio de año', () {
      expect(
        InstallmentPlanner.addMonths(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
      expect(
        InstallmentPlanner.addMonths(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
      expect(
        InstallmentPlanner.addMonths(DateTime(2026, 12, 31), 12),
        DateTime(2027, 12, 31),
      );
    });

    test('intervalo de 2 meses', () {
      final plan = InstallmentPlanner.even(
        principalMinor: 6000,
        count: 3,
        firstDue: DateTime(2026, 11, 10),
        intervalMonths: 2,
      );
      expect(plan.map((d) => d.dueAt.month), [11, 1, 3]);
    });

    test('valida parámetros', () {
      final d = DateTime(2026, 12, 1);
      expect(
        () => InstallmentPlanner.even(principalMinor: 0, count: 2, firstDue: d),
        throwsA(isA<PlanException>()),
      );
      expect(
        () =>
            InstallmentPlanner.even(principalMinor: 100, count: 0, firstDue: d),
        throwsA(isA<PlanException>()),
      );
      expect(
        () => InstallmentPlanner.even(principalMinor: 2, count: 5, firstDue: d),
        throwsA(isA<PlanException>()),
      );
      expect(
        () => InstallmentPlanner.even(
          principalMinor: 100,
          count: 2,
          firstDue: d,
          intervalMonths: 0,
        ),
        throwsA(isA<PlanException>()),
      );
    });
  });

  group('validate', () {
    InstallmentDraft d(int m) =>
        InstallmentDraft(dueAt: DateTime(2026, 12, 1), amountMinor: m);

    test(
      'suma exacta pasa',
      () => InstallmentPlanner.validate([d(7000), d(5000)], 12000),
    );

    test('falta o excede: mensaje con la diferencia', () {
      expect(
        () => InstallmentPlanner.validate([d(7000), d(4000)], 12000),
        throwsA(
          isA<PlanException>().having(
            (e) => e.message,
            'm',
            contains('Faltan S/ 10.00'),
          ),
        ),
      );
      expect(
        () => InstallmentPlanner.validate([d(7000), d(6000)], 12000),
        throwsA(
          isA<PlanException>().having(
            (e) => e.message,
            'm',
            contains('exceden el total en S/ 10.00'),
          ),
        ),
      );
    });

    test('vacío o importe no positivo', () {
      expect(
        () => InstallmentPlanner.validate([], 100),
        throwsA(isA<PlanException>()),
      );
      expect(
        () => InstallmentPlanner.validate([d(0), d(100)], 100),
        throwsA(isA<PlanException>()),
      );
    });
  });
}
