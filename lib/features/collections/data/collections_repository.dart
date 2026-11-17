import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';

class CollectionsRepository {
  CollectionsRepository(this._db, this._audit, this._uuid, this._clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const kinds = [
    'credit_sale',
    'loan',
    'fundraising',
    'service',
    'other',
  ];
  static const ownerships = ['self', 'third_party'];

  Stream<List<Collection>> watchActive({String? spaceId, String query = ''}) {
    final q = query.trim().toLowerCase();
    return (_db.select(_db.collections)
          ..where((c) => c.archivedAt.isNull())
          ..where(
            (c) => spaceId == null
                ? const Constant(true)
                : c.spaceId.equals(spaceId),
          )
          ..where(
            (c) =>
                q.isEmpty ? const Constant(true) : c.title.lower().like('%$q%'),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  Future<Collection?> find(String id) => (_db.select(
    _db.collections,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Collection> create({
    required String spaceId,
    required String title,
    String kind = 'other',
    String fundsOwnership = 'self',
    DateTime? dueAt,
    String? notes,
  }) async {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError('El título es obligatorio');
    if (!kinds.contains(kind)) {
      throw ArgumentError('Tipo de cobro inválido: $kind');
    }
    if (!ownerships.contains(fundsOwnership)) {
      throw ArgumentError('Titularidad de fondos inválida: $fundsOwnership');
    }
    final now = _clock();
    final id = _uuid.v4();
    return _db.transaction(() async {
      await _db
          .into(_db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              spaceId: spaceId,
              title: t,
              kind: Value(kind),
              fundsOwnership: Value(fundsOwnership),
              dueAt: Value(dueAt),
              notes: Value(notes),
            ),
          );
      await _audit.log(
        entityType: 'collection',
        entityId: id,
        action: 'create',
        newValues: {
          'title': t,
          'spaceId': spaceId,
          'kind': kind,
          'fundsOwnership': fundsOwnership,
        },
      );
      return (await find(id))!;
    });
  }

  Future<void> update(
    String id, {
    String? title,
    String? kind,
    DateTime? dueAt,
    String? notes,
  }) async {
    final old = await find(id);
    if (old == null) throw StateError('Cobro no encontrado');
    final t = title?.trim() ?? old.title;
    if (t.isEmpty) throw ArgumentError('El título es obligatorio');
    if (kind != null && !kinds.contains(kind)) {
      throw ArgumentError('Tipo de cobro inválido: $kind');
    }
    await _db.transaction(() async {
      await (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(
          title: Value(t),
          kind: Value(kind ?? old.kind),
          dueAt: Value(dueAt ?? old.dueAt),
          notes: Value(notes ?? old.notes),
          updatedAt: Value(_clock()),
        ),
      );
      await _audit.log(
        entityType: 'collection',
        entityId: id,
        action: 'update',
        oldValues: {'title': old.title, 'kind': old.kind},
        newValues: {'title': t, 'kind': kind ?? old.kind},
      );
    });
  }

  Future<void> archive(String id) async {
    await _db.transaction(() async {
      final now = _clock();
      await (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(archivedAt: Value(now), updatedAt: Value(now)),
      );
      await _audit.log(
        entityType: 'collection',
        entityId: id,
        action: 'archive',
      );
    });
  }
}
