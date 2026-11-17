import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/balance_calculator.dart';

/// Saldos derivados de obligaciones (consultas en lote para listas/totales).
/// Vencimiento pendiente de cobro (cuota o fecha límite de la obligación).
class DueItem {
  const DueItem({
    required this.receivableId,
    required this.contactId,
    required this.collectionId,
    required this.dueAt,
    required this.remainingMinor,
    required this.currency,
    required this.overdue,
  });

  final String receivableId;
  final String contactId;
  final String collectionId;
  final DateTime dueAt;
  final int remainingMinor;
  final String currency;
  final bool overdue;
}

class BalancesRepository {
  BalancesRepository(this._db, this._clock);

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Map<String, Balance>> _compute(List<Receivable> items) async {
    if (items.isEmpty) return {};
    final pays = await (_db.select(
      _db.payments,
    )..where((p) => p.receivableId.isIn(items.map((r) => r.id)))).get();
    final byReceivable = <String, List<PaymentLine>>{};
    for (final p in pays) {
      (byReceivable[p.receivableId] ??= []).add(
        PaymentLine(amountMinor: p.amountMinor, status: p.status),
      );
    }
    final now = _clock();
    return {
      for (final r in items)
        r.id: BalanceCalculator.receivable(
          principalMinor: r.principalMinor,
          payments: byReceivable[r.id] ?? const [],
          dueAt: r.dueAt,
          cancelled: r.cancelledAt != null,
          now: now,
        ),
    };
  }

  Future<Map<String, Balance>> forCollection(String collectionId) async {
    final items = await (_db.select(
      _db.receivables,
    )..where((r) => r.collectionId.equals(collectionId))).get();
    return _compute(items);
  }

  Future<Balance?> forReceivable(String receivableId) async {
    final r = await (_db.select(
      _db.receivables,
    )..where((x) => x.id.equals(receivableId))).getSingleOrNull();
    if (r == null) return null;
    return (await _compute([r]))[r.id];
  }

  Stream<Map<String, Balance>> watchCollection(String collectionId) => _db
      .watchTables({_db.receivables, _db.payments})
      .asyncMap((_) => forCollection(collectionId));

  Stream<Balance?> watchReceivable(String receivableId) => _db
      .watchTables({_db.receivables, _db.payments})
      .asyncMap((_) => forReceivable(receivableId));

  /// Totales globales o de un espacio (dashboard). Excluye cobros archivados.
  Future<CollectionTotals> totals({String? spaceId}) async {
    final q = _db.select(_db.receivables).join([
      innerJoin(
        _db.collections,
        _db.collections.id.equalsExp(_db.receivables.collectionId),
      ),
    ])..where(_db.collections.archivedAt.isNull());
    if (spaceId != null) q.where(_db.collections.spaceId.equals(spaceId));
    final items = [
      for (final row in await q.get()) row.readTable(_db.receivables),
    ];
    return BalanceCalculator.totals((await _compute(items)).values.toList());
  }

  Stream<CollectionTotals> watchTotals({String? spaceId}) => _db
      .watchTables({_db.receivables, _db.payments, _db.collections})
      .asyncMap((_) => totals(spaceId: spaceId));

  /// Próximos vencimientos (y vencidos), del más antiguo al más reciente.
  /// Con plan: la primera cuota con saldo; sin plan: la fecha límite de la
  /// obligación. Ignora pagadas, canceladas y cobros archivados.
  Future<List<DueItem>> upcomingDue({
    String? spaceId,
    int withinDays = 30,
    int limit = 10,
  }) async {
    final q =
        _db.select(_db.receivables).join([
          innerJoin(
            _db.collections,
            _db.collections.id.equalsExp(_db.receivables.collectionId),
          ),
        ])..where(
          _db.collections.archivedAt.isNull() &
              _db.receivables.cancelledAt.isNull(),
        );
    if (spaceId != null) q.where(_db.collections.spaceId.equals(spaceId));
    final receivables = [
      for (final row in await q.get()) row.readTable(_db.receivables),
    ];
    if (receivables.isEmpty) return [];

    final balances = await _compute(receivables);
    final ids = receivables.map((r) => r.id);
    final plans =
        await (_db.select(_db.installments)
              ..where((i) => i.receivableId.isIn(ids))
              ..orderBy([(i) => OrderingTerm.asc(i.sequence)]))
            .get();
    final allocs = plans.isEmpty
        ? <PaymentAllocation>[]
        : await (_db.select(
            _db.paymentAllocations,
          )..where((a) => a.installmentId.isIn(plans.map((i) => i.id)))).get();
    final paid = <String, int>{};
    for (final a in allocs) {
      paid[a.installmentId] = (paid[a.installmentId] ?? 0) + a.amountMinor;
    }
    final plansBy = <String, List<Installment>>{};
    for (final i in plans) {
      (plansBy[i.receivableId] ??= []).add(i);
    }

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(Duration(days: withinDays));
    final out = <DueItem>[];
    for (final r in receivables) {
      final b = balances[r.id]!;
      if (b.balanceMinor <= 0) continue;
      DateTime? due;
      var remaining = b.balanceMinor;
      final plan = plansBy[r.id];
      if (plan != null && plan.isNotEmpty) {
        for (final i in plan) {
          final left = i.amountMinor - (paid[i.id] ?? 0);
          if (left > 0) {
            due = i.dueAt;
            remaining = left;
            break;
          }
        }
      } else {
        due = r.dueAt;
      }
      if (due == null) continue;
      final day = DateTime(due.year, due.month, due.day);
      if (day.isAfter(horizon)) continue;
      out.add(
        DueItem(
          receivableId: r.id,
          contactId: r.contactId,
          collectionId: r.collectionId,
          dueAt: due,
          remainingMinor: remaining,
          currency: r.currency,
          overdue: day.isBefore(today),
        ),
      );
    }
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return out.take(limit).toList();
  }

  Stream<List<DueItem>> watchUpcomingDue({
    String? spaceId,
    int withinDays = 30,
    int limit = 10,
  }) => _db
      .watchTables({
        _db.receivables,
        _db.payments,
        _db.installments,
        _db.paymentAllocations,
        _db.collections,
      })
      .asyncMap(
        (_) =>
            upcomingDue(spaceId: spaceId, withinDays: withinDays, limit: limit),
      );

  /// Totales por cobro (una sola pasada) para la lista de Cobros.
  Future<Map<String, CollectionTotals>> totalsByCollection() async {
    final q = _db.select(_db.receivables).join([
      innerJoin(
        _db.collections,
        _db.collections.id.equalsExp(_db.receivables.collectionId),
      ),
    ])..where(_db.collections.archivedAt.isNull());
    final items = [
      for (final row in await q.get()) row.readTable(_db.receivables),
    ];
    final balances = await _compute(items);
    final grouped = <String, List<Balance>>{};
    for (final r in items) {
      (grouped[r.collectionId] ??= []).add(balances[r.id]!);
    }
    return {
      for (final e in grouped.entries) e.key: BalanceCalculator.totals(e.value),
    };
  }

  Stream<Map<String, CollectionTotals>> watchTotalsByCollection() => _db
      .watchTables({_db.receivables, _db.payments, _db.collections})
      .asyncMap((_) => totalsByCollection());
}
