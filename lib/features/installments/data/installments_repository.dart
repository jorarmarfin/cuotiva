import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
import '../domain/installment_planner.dart';
import 'allocation_service.dart';

enum InstallmentStatus { pending, partial, paid, overdue }

class InstallmentView {
  const InstallmentView({
    required this.installment,
    required this.paidMinor,
    required this.status,
  });
  final Installment installment;
  final int paidMinor;
  final InstallmentStatus status;
  int get remainingMinor => installment.amountMinor - paidMinor;
}

class InstallmentsRepository {
  InstallmentsRepository(this._db, this._audit, this._uuid, this._clock)
    : _allocations = AllocationService(_db, _uuid, _clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AllocationService _allocations;

  Future<List<Installment>> list(String receivableId) =>
      (_db.select(_db.installments)
            ..where((i) => i.receivableId.equals(receivableId))
            ..orderBy([(i) => OrderingTerm.asc(i.sequence)]))
          .get();

  /// Plan con estado derivado por cuota (pagado / parcial / vencido).
  Future<List<InstallmentView>> plan(String receivableId) async {
    final items = await list(receivableId);
    final paid = <String, int>{};
    if (items.isNotEmpty) {
      final rows = await (_db.select(
        _db.paymentAllocations,
      )..where((a) => a.installmentId.isIn(items.map((i) => i.id)))).get();
      for (final a in rows) {
        paid[a.installmentId] = (paid[a.installmentId] ?? 0) + a.amountMinor;
      }
    }
    final today = _clock();
    final day = DateTime(today.year, today.month, today.day);
    return [
      for (final i in items)
        InstallmentView(
          installment: i,
          paidMinor: paid[i.id] ?? 0,
          status: _status(i, paid[i.id] ?? 0, day),
        ),
    ];
  }

  Stream<List<InstallmentView>> watchPlan(String receivableId) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.installments, _db.paymentAllocations, _db.payments},
      )
      .watch()
      .asyncMap((_) => plan(receivableId));

  /// Reemplaza el plan completo. La suma debe ser exactamente el importe de
  /// la obligación; los pagos confirmados se reasignan a las nuevas cuotas.
  Future<void> setPlan(
    String receivableId,
    List<InstallmentDraft> drafts,
  ) => _db.transaction(() async {
    final r = await (_db.select(
      _db.receivables,
    )..where((x) => x.id.equals(receivableId))).getSingleOrNull();
    if (r == null) throw PlanException('Obligación no encontrada');
    if (r.cancelledAt != null) {
      throw PlanException('La obligación está cancelada');
    }
    InstallmentPlanner.validate(drafts, r.principalMinor);

    final old = await list(receivableId);
    // Las asignaciones son derivadas: se borran antes de reemplazar las cuotas (FK).
    await _db.customStatement(
      'DELETE FROM payment_allocations WHERE installment_id IN '
      '(SELECT id FROM installments WHERE receivable_id = ?)',
      [receivableId],
    );
    await (_db.delete(
      _db.installments,
    )..where((i) => i.receivableId.equals(receivableId))).go();

    final now = _clock();
    final sorted = [...drafts]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    for (var n = 0; n < sorted.length; n++) {
      await _db
          .into(_db.installments)
          .insert(
            InstallmentsCompanion.insert(
              id: _uuid.v4(),
              createdAt: now,
              updatedAt: now,
              receivableId: receivableId,
              sequence: n + 1,
              dueAt: sorted[n].dueAt,
              amountMinor: sorted[n].amountMinor,
            ),
          );
    }
    await _allocations.reallocate(receivableId);
    await _audit.log(
      entityType: 'receivable',
      entityId: receivableId,
      action: 'set_installment_plan',
      oldValues: {
        'installments': [
          for (final i in old)
            {'dueAt': i.dueAt.toIso8601String(), 'amountMinor': i.amountMinor},
        ],
      },
      newValues: {
        'installments': [
          for (final d in sorted)
            {'dueAt': d.dueAt.toIso8601String(), 'amountMinor': d.amountMinor},
        ],
      },
    );
  });

  /// Quita el plan: vuelve a modo libre (saldo directo).
  Future<void> clearPlan(String receivableId) => _db.transaction(() async {
    final old = await list(receivableId);
    if (old.isEmpty) return;
    await _db.customStatement(
      'DELETE FROM payment_allocations WHERE installment_id IN '
      '(SELECT id FROM installments WHERE receivable_id = ?)',
      [receivableId],
    );
    await (_db.delete(
      _db.installments,
    )..where((i) => i.receivableId.equals(receivableId))).go();
    await _audit.log(
      entityType: 'receivable',
      entityId: receivableId,
      action: 'clear_installment_plan',
      oldValues: {'count': old.length},
    );
  });

  InstallmentStatus _status(Installment i, int paid, DateTime today) {
    if (paid >= i.amountMinor) return InstallmentStatus.paid;
    final due = DateTime(i.dueAt.year, i.dueAt.month, i.dueAt.day);
    if (due.isBefore(today)) return InstallmentStatus.overdue;
    return paid > 0 ? InstallmentStatus.partial : InstallmentStatus.pending;
  }
}
