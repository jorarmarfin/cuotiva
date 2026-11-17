import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';

class SpacesRepository {
  SpacesRepository(this._db, this._audit, this._uuid, this._clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Stream<List<Space>> watchActive() =>
      (_db.select(_db.spaces)
            ..where((s) => s.archivedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .watch();

  Future<Space?> find(String id) =>
      (_db.select(_db.spaces)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Space> create({
    required String name,
    required int color,
    String type = 'other',
    String icon = 'folder',
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('El nombre es obligatorio');
    final now = _clock();
    final id = _uuid.v4();
    return _db.transaction(() async {
      await _db
          .into(_db.spaces)
          .insert(
            SpacesCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              name: trimmed,
              color: color,
              type: Value(type),
              icon: Value(icon),
              description: Value(description),
            ),
          );
      await _audit.log(
        entityType: 'space',
        entityId: id,
        action: 'create',
        newValues: {'name': trimmed, 'type': type},
      );
      return (await find(id))!;
    });
  }

  Future<void> update(
    String id, {
    String? name,
    int? color,
    String? type,
    String? icon,
    String? description,
  }) async {
    final old = await find(id);
    if (old == null) throw StateError('Espacio no encontrado');
    final newName = name?.trim() ?? old.name;
    if (newName.isEmpty) throw ArgumentError('El nombre es obligatorio');
    await _db.transaction(() async {
      await (_db.update(_db.spaces)..where((s) => s.id.equals(id))).write(
        SpacesCompanion(
          name: Value(newName),
          color: Value(color ?? old.color),
          type: Value(type ?? old.type),
          icon: Value(icon ?? old.icon),
          description: Value(description ?? old.description),
          updatedAt: Value(_clock()),
        ),
      );
      await _audit.log(
        entityType: 'space',
        entityId: id,
        action: 'update',
        oldValues: {'name': old.name, 'color': old.color, 'type': old.type},
        newValues: {
          'name': newName,
          'color': color ?? old.color,
          'type': type ?? old.type,
        },
      );
    });
  }

  /// Archiva (no borra): un espacio con cobros conserva su historial.
  Future<void> archive(String id) async {
    await _db.transaction(() async {
      final now = _clock();
      await (_db.update(_db.spaces)..where((s) => s.id.equals(id))).write(
        SpacesCompanion(archivedAt: Value(now), updatedAt: Value(now)),
      );
      await _audit.log(entityType: 'space', entityId: id, action: 'archive');
    });
  }
}
