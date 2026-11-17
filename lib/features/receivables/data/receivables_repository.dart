import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
import '../../../core/money/money.dart';
import '../domain/receivable_errors.dart';

/// Devuelve lo ya cobrado (pagos confirmados) de una obligación.
/// En la Fase 1 no hay pagos, por lo que el valor por defecto es 0;
/// la Fase 2 inyecta la consulta real.
typedef CollectedLookup = Future<int> Function(String receivableId);

class ReceivablesRepository {
  ReceivablesRepository(
    this._db,
    this._audit,
    this._uuid,
    this._clock, {
    CollectedLookup? collected,
  }) : _collected = collected ?? ((_) async => 0);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final CollectedLookup _collected;

  Stream<List<Receivable>> watchByCollection(String collectionId) =>
      (_db.select(_db.receivables)
            ..where((r) => r.collectionId.equals(collectionId))
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .watch();

  Stream<List<Receivable>> watchByContact(String contactId) => (_db.select(
    _db.receivables,
  )..where((r) => r.contactId.equals(contactId))).watch();

  Future<Receivable?> find(String id) => (_db.select(
    _db.receivables,
  )..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<Receivable> create({
    required String collectionId,
    required String contactId,
    required Money principal,
    DateTime? dueAt,
    String? notes,
  }) => _db.transaction(
    () => _insert(
      collectionId: collectionId,
      contactId: contactId,
      principal: principal,
      dueAt: dueAt,
      notes: notes,
    ),
  );

  /// Asigna el mismo importe a varios contactos (ej. S/ 150 a cada padre).
  /// Atómico: si alguno falla (p. ej. duplicado) no se crea ninguno.
  /// Omite los ya asignados solo si [skipExisting] es true.
  Future<List<Receivable>> bulkCreate({
    required String collectionId,
    required List<String> contactIds,
    required Money principal,
    DateTime? dueAt,
    bool skipExisting = false,
  }) {
    return _db.transaction(() async {
      final existing = skipExisting
          ? (await (_db.select(
                  _db.receivables,
                )..where((r) => r.collectionId.equals(collectionId))).get())
                .map((r) => r.contactId)
                .toSet()
          : <String>{};
      final result = <Receivable>[];
      for (final cid in contactIds.toSet()) {
        if (existing.contains(cid)) continue;
        result.add(
          await _insert(
            collectionId: collectionId,
            contactId: cid,
            principal: principal,
            dueAt: dueAt,
          ),
        );
      }
      return result;
    });
  }

  /// No permite bajar el importe por debajo de lo ya cobrado (§4.2).
  Future<void> updatePrincipal(String id, Money principal) async {
    if (!principal.isPositive) {
      throw ReceivableException('El importe debe ser mayor a cero');
    }
    final old = await find(id);
    if (old == null) throw ReceivableException('Obligación no encontrada');
    if (old.cancelledAt != null) {
      throw ReceivableException('La obligación está cancelada');
    }
    final plan = await (_db.select(
      _db.installments,
    )..where((i) => i.receivableId.equals(id))).get();
    if (plan.isNotEmpty && principal.minor != old.principalMinor) {
      throw ReceivableException(
        'Tiene un plan de cuotas: ajusta el plan para cambiar el importe',
      );
    }
    final collected = await _collected(id);
    if (principal.minor < collected) {
      throw ReceivableException(
        'No se puede reducir por debajo de lo ya cobrado '
        '(${Money.minor(collected, currency: old.currency).format()})',
      );
    }
    await _db.transaction(() async {
      await (_db.update(_db.receivables)..where((r) => r.id.equals(id))).write(
        ReceivablesCompanion(
          principalMinor: Value(principal.minor),
          updatedAt: Value(_clock()),
        ),
      );
      await _audit.log(
        entityType: 'receivable',
        entityId: id,
        action: 'update_principal',
        oldValues: {'principalMinor': old.principalMinor},
        newValues: {'principalMinor': principal.minor},
      );
    });
  }

  Future<void> cancel(String id) async {
    final old = await find(id);
    if (old == null) throw ReceivableException('Obligación no encontrada');
    if ((await _collected(id)) > 0) {
      throw ReceivableException(
        'Tiene pagos confirmados: anúlalos antes de cancelar',
      );
    }
    await _db.transaction(() async {
      final now = _clock();
      await (_db.update(_db.receivables)..where((r) => r.id.equals(id))).write(
        ReceivablesCompanion(cancelledAt: Value(now), updatedAt: Value(now)),
      );
      await _audit.log(
        entityType: 'receivable',
        entityId: id,
        action: 'cancel',
      );
    });
  }

  Future<Receivable> _insert({
    required String collectionId,
    required String contactId,
    required Money principal,
    DateTime? dueAt,
    String? notes,
  }) async {
    if (!principal.isPositive) {
      throw ReceivableException('El importe debe ser mayor a cero');
    }
    final dup =
        await (_db.select(_db.receivables)..where(
              (r) =>
                  r.collectionId.equals(collectionId) &
                  r.contactId.equals(contactId),
            ))
            .getSingleOrNull();
    if (dup != null) {
      throw ReceivableException(
        'La persona ya tiene una obligación en este cobro',
      );
    }
    final now = _clock();
    final id = _uuid.v4();
    await _db
        .into(_db.receivables)
        .insert(
          ReceivablesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            collectionId: collectionId,
            contactId: contactId,
            principalMinor: principal.minor,
            currency: Value(principal.currency),
            dueAt: Value(dueAt),
            notes: Value(notes),
          ),
        );
    await _audit.log(
      entityType: 'receivable',
      entityId: id,
      action: 'create',
      newValues: {
        'collectionId': collectionId,
        'contactId': contactId,
        'principalMinor': principal.minor,
        'currency': principal.currency,
      },
    );
    return (await find(id))!;
  }
}
