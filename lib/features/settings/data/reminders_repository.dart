import '../../../core/database/app_database.dart';
import '../../../core/notifications/reminder_planner.dart';

/// Cuotas y obligaciones con saldo y fecha de vencimiento (para recordatorios).
class RemindersRepository {
  RemindersRepository(this._db);
  final AppDatabase _db;

  /// Se re-emite cuando cambian datos que afectan a los recordatorios.
  Stream<void> watchChanges() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.payments,
          _db.installments,
          _db.receivables,
          _db.collections,
          _db.contacts,
        },
      )
      .watch()
      .map((_) {});

  Future<List<DueItem>> dueItems() async {
    final cols = {
      for (final c in await _db.select(_db.collections).get()) c.id: c,
    };
    final names = {
      for (final c in await _db.select(_db.contacts).get()) c.id: c.displayName,
    };
    final installments = <String, List<Installment>>{};
    for (final i in await _db.select(_db.installments).get()) {
      (installments[i.receivableId] ??= []).add(i);
    }
    final confirmed = <String, int>{};
    for (final p in await (_db.select(
      _db.payments,
    )..where((p) => p.status.equals('confirmed'))).get()) {
      confirmed[p.receivableId] =
          (confirmed[p.receivableId] ?? 0) + p.amountMinor;
    }
    final allocated = <String, int>{};
    for (final a in await _db.select(_db.paymentAllocations).get()) {
      allocated[a.installmentId] =
          (allocated[a.installmentId] ?? 0) + a.amountMinor;
    }

    final out = <DueItem>[];
    for (final r in await _db.select(_db.receivables).get()) {
      if (r.cancelledAt != null) continue;
      final col = cols[r.collectionId];
      if (col == null || col.archivedAt != null) continue;
      final person = names[r.contactId] ?? 'Persona';
      final plan = installments[r.id];
      if (plan != null && plan.isNotEmpty) {
        for (final i in plan) {
          final left = i.amountMinor - (allocated[i.id] ?? 0);
          if (left > 0) {
            out.add(
              DueItem(
                key: 'inst:${i.id}',
                person: person,
                concept: col.title,
                dueAt: i.dueAt,
                amountMinor: left,
              ),
            );
          }
        }
      } else {
        final due = r.dueAt ?? col.dueAt;
        final left = r.principalMinor - (confirmed[r.id] ?? 0);
        if (due != null && left > 0) {
          out.add(
            DueItem(
              key: 'rec:${r.id}',
              person: person,
              concept: col.title,
              dueAt: due,
              amountMinor: left,
            ),
          );
        }
      }
    }
    return out;
  }
}
