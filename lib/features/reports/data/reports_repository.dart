import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../receivables/domain/balance_calculator.dart';
import '../../receivables/domain/status_labels.dart';
import '../domain/report_models.dart';

/// Arma los datos de los PDF a partir de la base. Solo lectura: no modifica
/// nada. Los movimientos confirmados y los pendientes van separados.
class ReportsRepository {
  ReportsRepository(this._db, this._clock);

  final AppDatabase _db;
  final DateTime Function() _clock;

  Balance _balance(Receivable r, List<Payment> pays) =>
      BalanceCalculator.receivable(
        principalMinor: r.principalMinor,
        payments: [
          for (final p in pays)
            PaymentLine(amountMinor: p.amountMinor, status: p.status),
        ],
        dueAt: r.dueAt,
        cancelled: r.cancelledAt != null,
        now: _clock(),
      );

  Future<StatementData> statementFor(String receivableId) async {
    final r = await (_db.select(
      _db.receivables,
    )..where((x) => x.id.equals(receivableId))).getSingle();
    final col = await (_db.select(
      _db.collections,
    )..where((x) => x.id.equals(r.collectionId))).getSingle();
    final space = await (_db.select(
      _db.spaces,
    )..where((x) => x.id.equals(col.spaceId))).getSingle();
    final contact = await (_db.select(
      _db.contacts,
    )..where((x) => x.id.equals(r.contactId))).getSingle();
    final pays =
        await (_db.select(_db.payments)
              ..where((p) => p.receivableId.equals(receivableId))
              ..orderBy([
                (p) => OrderingTerm.asc(p.occurredAt),
                (p) => OrderingTerm.asc(p.createdAt),
              ]))
            .get();
    final installments =
        await (_db.select(_db.installments)
              ..where((i) => i.receivableId.equals(receivableId))
              ..orderBy([(i) => OrderingTerm.asc(i.sequence)]))
            .get();
    final allocs = installments.isEmpty
        ? <PaymentAllocation>[]
        : await (_db.select(_db.paymentAllocations)..where(
                (a) => a.installmentId.isIn(installments.map((i) => i.id)),
              ))
              .get();
    final paidBy = <String, int>{};
    for (final a in allocs) {
      paidBy[a.installmentId] = (paidBy[a.installmentId] ?? 0) + a.amountMinor;
    }
    StatementMovement mv(Payment p) => StatementMovement(
      date: p.occurredAt,
      method: p.method,
      amountMinor: p.amountMinor,
      reference: p.reference,
    );
    final b = _balance(r, pays);
    return StatementData(
      spaceName: space.name,
      collectionTitle: col.title,
      personName: contact.displayName,
      phone: contact.phone,
      notes: r.notes,
      currency: r.currency,
      principalMinor: r.principalMinor,
      confirmedMinor: b.confirmedMinor,
      balanceMinor: b.balanceMinor,
      statusLabel: receivableStatusLabel(b.status),
      confirmed: [
        for (final p in pays)
          if (p.status == 'confirmed') mv(p),
      ],
      pending: [
        for (final p in pays)
          if (p.status == 'pending_verification') mv(p),
      ],
      installments: [
        for (final i in installments)
          StatementInstallment(
            sequence: i.sequence,
            dueAt: i.dueAt,
            amountMinor: i.amountMinor,
            paidMinor: paidBy[i.id] ?? 0,
          ),
      ],
      issuedAt: _clock(),
    );
  }

  Future<CampaignReportData> campaignReport(String collectionId) async {
    final col = await (_db.select(
      _db.collections,
    )..where((x) => x.id.equals(collectionId))).getSingle();
    final space = await (_db.select(
      _db.spaces,
    )..where((x) => x.id.equals(col.spaceId))).getSingle();
    final recs = await (_db.select(
      _db.receivables,
    )..where((r) => r.collectionId.equals(collectionId))).get();
    final contacts = {
      for (final c in await _db.select(_db.contacts).get()) c.id: c.displayName,
    };
    final pays = recs.isEmpty
        ? <Payment>[]
        : await (_db.select(
            _db.payments,
          )..where((p) => p.receivableId.isIn(recs.map((r) => r.id)))).get();
    final rows = <CampaignParticipantRow>[];
    final balances = <Balance>[];
    for (final r in recs) {
      if (r.cancelledAt != null) continue;
      final b = _balance(r, pays.where((p) => p.receivableId == r.id).toList());
      balances.add(b);
      rows.add(
        CampaignParticipantRow(
          name: contacts[r.contactId] ?? 'Persona',
          principalMinor: b.principalMinor,
          confirmedMinor: b.confirmedMinor,
          balanceMinor: b.balanceMinor,
          statusLabel: receivableStatusLabel(b.status),
        ),
      );
    }
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final t = BalanceCalculator.totals(balances);
    final sets =
        await (_db.select(_db.settlements)
              ..where(
                (s) =>
                    s.collectionId.equals(collectionId) &
                    s.status.equals('confirmed'),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.occurredAt)]))
            .get();
    return CampaignReportData(
      spaceName: space.name,
      title: col.title,
      thirdParty: col.fundsOwnership == 'third_party',
      committedMinor: t.committedMinor,
      collectedMinor: t.collectedMinor,
      pendingMinor: t.pendingMinor,
      overdueMinor: t.overdueMinor,
      participants: rows,
      deliveredMinor: sets.fold(0, (a, s) => a + s.amountMinor),
      settlements: [
        for (final s in sets)
          StatementMovement(
            date: s.occurredAt,
            method: 'other',
            amountMinor: s.amountMinor,
            reference: s.recipientName,
          ),
      ],
      issuedAt: _clock(),
    );
  }

  /// Listado filtrable para la pantalla Reportes (filtra en memoria: el
  /// volumen mono-usuario es pequeño).
  Future<List<ObligationRow>> search(ReportFilter f) async {
    final spaces = {
      for (final s in await _db.select(_db.spaces).get()) s.id: s,
    };
    final cols = {
      for (final c in await _db.select(_db.collections).get()) c.id: c,
    };
    final contacts = {
      for (final c in await _db.select(_db.contacts).get()) c.id: c.displayName,
    };
    final pays = <String, List<Payment>>{};
    for (final p in await _db.select(_db.payments).get()) {
      (pays[p.receivableId] ??= []).add(p);
    }
    final q = f.personQuery.trim().toLowerCase();
    final rows = <ObligationRow>[];
    for (final r in await _db.select(_db.receivables).get()) {
      final col = cols[r.collectionId];
      if (col == null || col.archivedAt != null) continue;
      if (spaces[col.spaceId]?.archivedAt != null) continue;
      if (f.spaceId != null && col.spaceId != f.spaceId) continue;
      if (f.collectionId != null && col.id != f.collectionId) continue;
      final person = contacts[r.contactId] ?? 'Persona';
      if (q.isNotEmpty && !person.toLowerCase().contains(q)) continue;
      final due = r.dueAt ?? col.dueAt;
      if (f.dueFrom != null && (due == null || due.isBefore(f.dueFrom!))) {
        continue;
      }
      if (f.dueTo != null &&
          (due == null ||
              due.isAfter(
                DateTime(
                  f.dueTo!.year,
                  f.dueTo!.month,
                  f.dueTo!.day,
                  23,
                  59,
                  59,
                ),
              ))) {
        continue;
      }
      final b = _balance(r, pays[r.id] ?? const []);
      if (f.status != null && b.status.name != f.status) continue;
      rows.add(
        ObligationRow(
          receivableId: r.id,
          collectionId: col.id,
          person: person,
          collectionTitle: col.title,
          principalMinor: r.principalMinor,
          balanceMinor: b.balanceMinor,
          status: b.status.name,
          dueAt: due,
        ),
      );
    }
    rows.sort(
      (a, b) => a.person.toLowerCase().compareTo(b.person.toLowerCase()),
    );
    return rows;
  }
}
