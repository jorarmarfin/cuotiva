import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentLine p(int amount, String status) =>
    PaymentLine(amountMinor: amount, status: status);

void main() {
  final today = DateTime(2026, 11, 17, 15, 30);

  Balance calc({
    int principal = 12000,
    List<PaymentLine> payments = const [],
    DateTime? dueAt,
    bool cancelled = false,
  }) => BalanceCalculator.receivable(
    principalMinor: principal,
    payments: payments,
    dueAt: dueAt,
    cancelled: cancelled,
    now: today,
  );

  group('saldo y recaudado', () {
    test('sin pagos: saldo = importe, estado pending', () {
      final b = calc();
      expect(b.balanceMinor, 12000);
      expect(b.confirmedMinor, 0);
      expect(b.status, ReceivableStatus.pending);
    });

    test('múltiples pagos confirmados (30 + 40 + 50 sobre 120)', () {
      var b = calc(payments: [p(3000, 'confirmed')]);
      expect(b.balanceMinor, 9000);
      expect(b.status, ReceivableStatus.partial);
      b = calc(payments: [p(3000, 'confirmed'), p(4000, 'confirmed')]);
      expect(b.balanceMinor, 5000);
      b = calc(
        payments: [
          p(3000, 'confirmed'),
          p(4000, 'confirmed'),
          p(5000, 'confirmed'),
        ],
      );
      expect(b.balanceMinor, 0);
      expect(b.status, ReceivableStatus.paid);
    });

    test('pago pendiente de verificación NO descuenta saldo', () {
      final b = calc(
        payments: [p(3000, 'confirmed'), p(4000, 'pending_verification')],
      );
      expect(b.balanceMinor, 9000);
      expect(b.confirmedMinor, 3000);
      expect(b.pendingVerificationMinor, 4000);
      expect(b.status, ReceivableStatus.partial);
    });

    test('rechazados y anulados no cuentan; anular restaura el saldo', () {
      expect(calc(payments: [p(3000, 'rejected')]).balanceMinor, 12000);
      final voided = calc(payments: [p(12000, 'voided')]);
      expect(voided.balanceMinor, 12000);
      expect(voided.status, ReceivableStatus.pending);
      expect(voided.pendingVerificationMinor, 0);
    });

    test('paid solo con saldo confirmado cero (pendiente no basta)', () {
      final b = calc(payments: [p(12000, 'pending_verification')]);
      expect(b.status, isNot(ReceivableStatus.paid));
      expect(b.balanceMinor, 12000);
    });

    test('estado de pago desconocido lanza error', () {
      expect(() => calc(payments: [p(100, 'raro')]), throwsArgumentError);
    });
  });

  group('vencimiento (fechas límite)', () {
    test('vence hoy: aún no está vencida', () {
      expect(
        calc(dueAt: DateTime(2026, 11, 17)).status,
        ReceivableStatus.pending,
      );
      expect(
        calc(dueAt: DateTime(2026, 11, 17, 23, 59)).status,
        ReceivableStatus.pending,
      );
    });

    test('venció ayer: overdue', () {
      expect(
        calc(dueAt: DateTime(2026, 11, 16, 23, 59)).status,
        ReceivableStatus.overdue,
      );
    });

    test('vence mañana: no vencida', () {
      expect(
        calc(dueAt: DateTime(2026, 11, 18)).status,
        ReceivableStatus.pending,
      );
    });

    test('vencida con abono parcial sigue overdue', () {
      final b = calc(
        dueAt: DateTime(2026, 11, 1),
        payments: [p(3000, 'confirmed')],
      );
      expect(b.status, ReceivableStatus.overdue);
    });

    test('pagada nunca es overdue aunque la fecha haya pasado', () {
      final b = calc(
        dueAt: DateTime(2026, 1, 1),
        payments: [p(12000, 'confirmed')],
      );
      expect(b.status, ReceivableStatus.paid);
    });

    test('cambio de año: 31 dic vs 1 ene', () {
      final b = BalanceCalculator.receivable(
        principalMinor: 100,
        payments: const [],
        dueAt: DateTime(2026, 12, 31),
        now: DateTime(2027, 1, 1, 0, 1),
      );
      expect(b.status, ReceivableStatus.overdue);
    });
  });

  test('cancelada: estado cancelled y no aporta saldo', () {
    final b = calc(cancelled: true, payments: [p(3000, 'confirmed')]);
    expect(b.status, ReceivableStatus.cancelled);
    expect(b.balanceMinor, 0);
  });

  test('exceso (dato inconsistente) no genera saldo negativo', () {
    final b = calc(payments: [p(15000, 'confirmed')]);
    expect(b.balanceMinor, 0);
    expect(b.status, ReceivableStatus.paid);
  });

  group('totales de cobro', () {
    test(
      'suma comprometido, recaudado, pendiente y vencido; excluye canceladas',
      () {
        final list = [
          calc(principal: 15000, payments: [p(5000, 'confirmed')]),
          calc(principal: 15000, dueAt: DateTime(2026, 11, 1)),
          calc(principal: 15000, payments: [p(15000, 'confirmed')]),
          calc(principal: 99999, cancelled: true),
        ];
        final t = BalanceCalculator.totals(list);
        expect(t.committedMinor, 45000);
        expect(t.collectedMinor, 20000);
        expect(t.pendingMinor, 25000);
        expect(t.overdueMinor, 15000);
        expect(t.participants, 3);
      },
    );

    test('20 participantes: comprometido = suma de obligaciones', () {
      final list = [for (var i = 0; i < 20; i++) calc(principal: 15000)];
      expect(BalanceCalculator.totals(list).committedMinor, 300000);
    });

    test('avance como fracción 0..1', () {
      final t = BalanceCalculator.totals([
        calc(principal: 10000, payments: [p(2500, 'confirmed')]),
      ]);
      expect(t.progress, closeTo(0.25, 1e-9));
      expect(BalanceCalculator.totals(const []).progress, 0);
    });
  });
}
