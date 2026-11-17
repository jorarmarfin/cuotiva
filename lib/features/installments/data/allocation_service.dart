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
    final now = _clock();

    Future<void> apply(Payment p, int index, int take) async {
      await _db
          .into(_db.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: _uuid.v4(),
              createdAt: now,
              updatedAt: now,
              paymentId: p.id,
              installmentId: installments[index].id,
              amountMinor: take,
            ),
          );
      remaining[index] -= take;
    }

    // 1) Pagos dirigidos a una cuota: primero a esa cuota; lo que sobre cae
    //    en el reparto automático.
    final leftover = <Payment, int>{};
    for (final p in payments) {
      var left = p.amountMinor;
      final target = installments.indexWhere((i) => i.id == p.installmentId);
      if (target >= 0 && remaining[target] > 0) {
        final take = left < remaining[target] ? left : remaining[target];
        await apply(p, target, take);
        left -= take;
      }
      if (left > 0) leftover[p] = left;
    }
    // 2) Resto y pagos automáticos: la cuota más antigua con saldo primero.
    for (final p in payments) {
      var left = leftover[p] ?? 0;
      for (var idx = 0; left > 0 && idx < installments.length; idx++) {
        if (remaining[idx] == 0) continue;
        final take = left < remaining[idx] ? left : remaining[idx];
        final done = await _existing(p.id, installments[idx].id);
        if (done != null) {
          await (_db.update(
            _db.paymentAllocations,
          )..where((a) => a.id.equals(done.id))).write(
            PaymentAllocationsCompanion(
              amountMinor: Value(done.amountMinor + take),
            ),
          );
          remaining[idx] -= take;
        } else {
          await apply(p, idx, take);
        }
        left -= take;
      }
    }
  }

  Future<PaymentAllocation?> _existing(
    String paymentId,
    String installmentId,
  ) =>
      (_db.select(_db.paymentAllocations)..where(
            (a) =>
                a.paymentId.equals(paymentId) &
                a.installmentId.equals(installmentId),
          ))
          .getSingleOrNull();

  Future<void> _clear(String receivableId) async {
    await _db.customStatement(
      'DELETE FROM payment_allocations WHERE installment_id IN '
      '(SELECT id FROM installments WHERE receivable_id = ?)',
      [receivableId],
    );
  }
}
