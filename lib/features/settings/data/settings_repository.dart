import '../../../core/database/app_database.dart';
import '../../../core/notifications/reminder_planner.dart';

/// Clave/valor sobre `app_settings` (la base ya está cifrada).
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> get(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> set(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  static const _reminders = 'reminders';

  Future<ReminderSettings> reminderSettings() async =>
      ReminderSettings.decode(await get(_reminders));

  Future<void> saveReminderSettings(ReminderSettings s) =>
      set(_reminders, s.encode());
}
