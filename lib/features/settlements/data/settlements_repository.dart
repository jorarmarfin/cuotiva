import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
import '../../../core/money/money.dart';
import '../domain/settlement_errors.dart';
import '../domain/settlement_summary.dart';

/// Entregas (rendiciones) del dinero recaudado en cobros de terceros.
/// No tocan obligaciones ni pagos: las deudas de los participantes no cambian.
class SettlementsRepository {
  SettlementsRepository(this._db, this._audit, this._uuid, this._clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Stream<List<Settlement>> watchByCollection(String collectionId) =>
      (_db.select(_db.settlements)
            ..where((s) => s.collectionId.equals(collectionId))
            ..orderBy([
              (s) => OrderingTerm.desc(s.occurredAt),
              (s) => OrderingTerm.desc(s.createdAt),
            ]))
          .watch();

  Future<Settlement?> find(String id) => (_db.select(
    _db.settlements,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> _collected(String collectionId) async {
    final sum = _db.payments.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.payments).join([
                innerJoin(
                  _db.receivables,
                  _db.receivables.id.equalsExp(_db.payments.receivableId),
                ),
              ])
              ..addColumns([sum])
              ..where(
                _db.receivables.collectionId.equals(collectionId) &
                    _db.payments.status.equals('confirmed'),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<int> _delivered(String collectionId) async {
    final sum = _db.settlements.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.settlements)
              ..addColumns([sum])
              ..where(
                _db.settlements.collectionId.equals(collectionId) &
                    _db.settlements.status.equals('confirmed'),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<SettlementSummary> summaryOf(String collectionId) async =>
      SettlementSummary(
        collectedMinor: await _collected(collectionId),
        deliveredMinor: await _delivered(collectionId),
      );

  /// Se re-emite al cambiar pagos o entregas.
  Stream<SettlementSummary> watchSummary(String collectionId) {
    final q = _db.customSelect(
      'SELECT 1',
      readsFrom: {_db.payments, _db.settlements, _db.receivables},
    );
    return q.watch().asyncMap((_) => summaryOf(collectionId));
  }

  /// Registra una entrega. Bloquea entregas mayores a lo pendiente por entregar.
  Future<Settlement> register({
    required String collectionId,
    required Money amount,
    DateTime? occurredAt,
    String? recipientName,
    String? notes,
  }) async {
    if (!amount.isPositive) {
      throw SettlementException('El importe debe ser mayor a cero');
    }
    final now = _clock();
    final id = _uuid.v4();
    return _db.transaction(() async {
      final c = await (_db.select(
        _db.collections,
      )..where((x) => x.id.equals(collectionId))).getSingleOrNull();
      if (c == null) throw SettlementException('Cobro no encontrado');
      if (c.fundsOwnership != 'third_party') {
        throw SettlementException(
          'Solo los cobros de fondos de terceros admiten entregas',
        );
      }
      if (amount.currency != 'PEN') {
        throw SettlementException('Moneda no soportada: ${amount.currency}');
      }
      final summary = await summaryOf(collectionId);
      if (amount.minor > summary.toDeliverMinor) {
        throw SettlementException(
          'La entrega (${amount.format()}) excede lo pendiente por entregar '
          '(${Money.minor(summary.toDeliverMinor, currency: amount.currency).format()})',
        );
      }
      await _db
          .into(_db.settlements)
          .insert(
            SettlementsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              collectionId: collectionId,
              amountMinor: amount.minor,
              currency: Value(amount.currency),
              occurredAt: occurredAt ?? now,
              recipientName: Value(_clean(recipientName)),
              notes: Value(_clean(notes)),
            ),
          );
      await _audit.log(
        entityType: 'settlement',
        entityId: id,
        action: 'register',
        newValues: {
          'collectionId': collectionId,
          'amountMinor': amount.minor,
          'recipientName': _clean(recipientName),
        },
      );
      return (await find(id))!;
    });
  }

  /// Anula una entrega (sin borrarla) con motivo obligatorio.
  Future<void> voidSettlement(String id, {required String reason}) =>
      _db.transaction(() async {
        final s = await find(id);
        if (s == null) throw SettlementException('Entrega no encontrada');
        if (s.status != 'confirmed') {
          throw SettlementException('La entrega ya está anulada');
        }
        final why = _clean(reason);
        if (why == null) {
          throw SettlementException('Indica el motivo de la anulación');
        }
        final now = _clock();
        await (_db.update(
          _db.settlements,
        )..where((x) => x.id.equals(id))).write(
          SettlementsCompanion(
            status: const Value('voided'),
            voidedAt: Value(now),
            voidReason: Value(why),
            updatedAt: Value(now),
          ),
        );
        await _audit.log(
          entityType: 'settlement',
          entityId: id,
          action: 'void',
          oldValues: {'status': s.status},
          newValues: {'status': 'voided', 'reason': why},
        );
      });

  String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
