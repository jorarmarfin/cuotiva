import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Registra cambios críticos en `audit_logs`. Llamar dentro de
/// `db.transaction(...)` para que el cambio y su auditoría sean atómicos.
class AuditService {
  AuditService(this._db, this._uuid, this._clock);

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<void> log({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, Object?>? oldValues,
    Map<String, Object?>? newValues,
  }) async {
    final now = _clock();
    await _db
        .into(_db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: _uuid.v4(),
            createdAt: now,
            updatedAt: now,
            entityType: entityType,
            entityId: entityId,
            action: action,
            oldValuesJson: Value(
              oldValues == null ? null : jsonEncode(oldValues),
            ),
            newValuesJson: Value(
              newValues == null ? null : jsonEncode(newValues),
            ),
            occurredAt: now,
          ),
        );
  }

  /// Historial de un registro, del más reciente al más antiguo.
  Stream<List<AuditLog>> watchFor(String entityType, String entityId) =>
      (_db.select(_db.auditLogs)
            ..where(
              (l) =>
                  l.entityType.equals(entityType) & l.entityId.equals(entityId),
            )
            ..orderBy([
              (l) => OrderingTerm.desc(l.occurredAt),
              (l) => OrderingTerm.desc(l.createdAt),
            ]))
          .watch();
}
