import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/balance_calculator.dart';

/// Saldos derivados de obligaciones (consultas en lote para listas/totales).
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
      .customSelect('SELECT 1', readsFrom: {_db.receivables, _db.payments})
      .watch()
      .asyncMap((_) => forCollection(collectionId));

  Stream<Balance?> watchReceivable(String receivableId) => _db
      .customSelect('SELECT 1', readsFrom: {_db.receivables, _db.payments})
      .watch()
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
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.receivables, _db.payments, _db.collections},
      )
      .watch()
      .asyncMap((_) => totals(spaceId: spaceId));
}
