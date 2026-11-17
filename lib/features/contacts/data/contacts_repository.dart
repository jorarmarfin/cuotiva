import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';

class ContactsRepository {
  ContactsRepository(this._db, this._audit, this._uuid, this._clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Solo dígitos y "+" inicial; null si queda vacío.
  static String? normalizePhone(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return t.startsWith('+') ? '+$digits' : digits;
  }

  Stream<List<Contact>> watchActive({String query = ''}) {
    final q = query.trim().toLowerCase();
    return (_db.select(_db.contacts)
          ..where((c) => c.archivedAt.isNull())
          ..where(
            (c) => q.isEmpty
                ? const Constant(true)
                : c.displayName.lower().like('%$q%'),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.displayName)]))
        .watch();
  }

  Future<Contact?> find(String id) => (_db.select(
    _db.contacts,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Contact> create({
    required String displayName,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('El nombre es obligatorio');
    final now = _clock();
    final id = _uuid.v4();
    return _db.transaction(() async {
      await _db
          .into(_db.contacts)
          .insert(
            ContactsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              displayName: name,
              phone: Value(normalizePhone(phone)),
              email: Value(
                email?.trim().isEmpty ?? true ? null : email!.trim(),
              ),
              notes: Value(notes),
            ),
          );
      await _audit.log(
        entityType: 'contact',
        entityId: id,
        action: 'create',
        newValues: {'displayName': name},
      );
      return (await find(id))!;
    });
  }

  Future<void> update(
    String id, {
    String? displayName,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final old = await find(id);
    if (old == null) throw StateError('Contacto no encontrado');
    final name = displayName?.trim() ?? old.displayName;
    if (name.isEmpty) throw ArgumentError('El nombre es obligatorio');
    await _db.transaction(() async {
      await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
        ContactsCompanion(
          displayName: Value(name),
          phone: Value(phone == null ? old.phone : normalizePhone(phone)),
          email: Value(email ?? old.email),
          notes: Value(notes ?? old.notes),
          updatedAt: Value(_clock()),
        ),
      );
      await _audit.log(
        entityType: 'contact',
        entityId: id,
        action: 'update',
        oldValues: {'displayName': old.displayName},
        newValues: {'displayName': name},
      );
    });
  }

  Future<void> archive(String id) async {
    await _db.transaction(() async {
      final now = _clock();
      await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
        ContactsCompanion(archivedAt: Value(now), updatedAt: Value(now)),
      );
      await _audit.log(entityType: 'contact', entityId: id, action: 'archive');
    });
  }
}
