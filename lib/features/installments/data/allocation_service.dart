import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

/// Distribuye los pagos CONFIRMADOS de una obligación entre sus cuotas
/// (más antigua primero). Es un dato derivado: se recalcula completo cada vez
/// que cambia un pago o el plan, así nunca queda inconsistente.
/// Sin plan de cuotas no hay asignaciones: el pago afecta el saldo directo.
class AllocationService {
  AllocationService(this._db, this._uuid, this._clock);

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Llamar dentro de la misma transacción que modifica pagos o cuotas.
  Future<void> reallocate(String receivableId) async {
    final installments =
        await (_db.select(_db.installments)
              ..where((i) => i.receivableId.equals(receivableId))
              ..orderBy([(i) => OrderingTerm.asc(i.sequence)]))
            .get();

    await _clear(receivableId);
    if (installments.isEmpty) return;

    final payments =
        await (_db.select(_db.payments)
              ..where(
                (p) =>
                    p.receivableId.equals(receivableId) &
                    p.status.equals('confirmed'),
              )
              ..orderBy([
                (p) => OrderingTerm.asc(p.occurredAt),
                (p) => OrderingTerm.asc(p.createdAt),
              ]))
            .get();

    final remaining = [for (final i in installments) i.amountMinor];
    var idx = 0;
    final now = _clock();
    for (final p in payments) {
      var left = p.amountMinor;
      while (left > 0 && idx < installments.length) {
        final take = left < remaining[idx] ? left : remaining[idx];
        if (take > 0) {
          await _db
              .into(_db.paymentAllocations)
              .insert(
                PaymentAllocationsCompanion.insert(
                  id: _uuid.v4(),
                  createdAt: now,
                  updatedAt: now,
                  paymentId: p.id,
                  installmentId: installments[idx].id,
                  amountMinor: take,
                ),
              );
          remaining[idx] -= take;
          left -= take;
        }
        if (remaining[idx] == 0) idx++;
      }
    }
  }

  Future<void> _clear(String receivableId) async {
    await _db.customStatement(
      'DELETE FROM payment_allocations WHERE installment_id IN '
      '(SELECT id FROM installments WHERE receivable_id = ?)',
      [receivableId],
    );
  }
}
