/// Cálculo de saldos y estados (CUOTIVA_SPEC §4.1 y §4.2).
/// Puro y sin dependencias: toda la lógica de dinero se prueba aquí.
library;

enum ReceivableStatus { pending, partial, paid, overdue, cancelled }

class PaymentLine {
  const PaymentLine({required this.amountMinor, required this.status});
  final int amountMinor;
  final String status;
}

class Balance {
  const Balance({
    required this.principalMinor,
    required this.confirmedMinor,
    required this.pendingVerificationMinor,
    required this.balanceMinor,
    required this.status,
  });

  final int principalMinor;

  /// Suma de pagos `confirmed`.
  final int confirmedMinor;

  /// Pagos `pending_verification`: informativos, NO descuentan saldo.
  final int pendingVerificationMinor;

  /// Saldo por cobrar (nunca negativo).
  final int balanceMinor;
  final ReceivableStatus status;
}

class CollectionTotals {
  const CollectionTotals({
    required this.committedMinor,
    required this.collectedMinor,
    required this.pendingMinor,
    required this.overdueMinor,
    required this.participants,
  });

  final int committedMinor;
  final int collectedMinor;
  final int pendingMinor;
  final int overdueMinor;
  final int participants;

  double get progress =>
      committedMinor == 0 ? 0 : collectedMinor / committedMinor;
}

abstract final class BalanceCalculator {
  static const _statuses = {
    'pending_verification',
    'confirmed',
    'rejected',
    'voided',
  };

  static Balance receivable({
    required int principalMinor,
    required List<PaymentLine> payments,
    required DateTime now,
    DateTime? dueAt,
    bool cancelled = false,
  }) {
    var confirmed = 0;
    var pending = 0;
    for (final p in payments) {
      if (!_statuses.contains(p.status)) {
        throw ArgumentError.value(
          p.status,
          'status',
          'Estado de pago desconocido',
        );
      }
      if (p.status == 'confirmed') confirmed += p.amountMinor;
      if (p.status == 'pending_verification') pending += p.amountMinor;
    }

    if (cancelled) {
      return Balance(
        principalMinor: principalMinor,
        confirmedMinor: confirmed,
        pendingVerificationMinor: pending,
        balanceMinor: 0,
        status: ReceivableStatus.cancelled,
      );
    }

    final balance = (principalMinor - confirmed).clamp(0, principalMinor);
    final ReceivableStatus status;
    if (balance == 0) {
      status = ReceivableStatus.paid;
    } else if (dueAt != null && _dateOnly(dueAt).isBefore(_dateOnly(now))) {
      status = ReceivableStatus.overdue;
    } else if (confirmed > 0) {
      status = ReceivableStatus.partial;
    } else {
      status = ReceivableStatus.pending;
    }
    return Balance(
      principalMinor: principalMinor,
      confirmedMinor: confirmed,
      pendingVerificationMinor: pending,
      balanceMinor: balance,
      status: status,
    );
  }

  /// Totales de un cobro/espacio. Las obligaciones canceladas no cuentan.
  static CollectionTotals totals(List<Balance> balances) {
    var committed = 0;
    var collected = 0;
    var pending = 0;
    var overdue = 0;
    var n = 0;
    for (final b in balances) {
      if (b.status == ReceivableStatus.cancelled) continue;
      n++;
      committed += b.principalMinor;
      collected += b.confirmedMinor > b.principalMinor
          ? b.principalMinor
          : b.confirmedMinor;
      pending += b.balanceMinor;
      if (b.status == ReceivableStatus.overdue) overdue += b.balanceMinor;
    }
    return CollectionTotals(
      committedMinor: committed,
      collectedMinor: collected,
      pendingMinor: pending,
      overdueMinor: overdue,
      participants: n,
    );
  }

  /// Vence al terminar el día límite: comparar solo la fecha.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
