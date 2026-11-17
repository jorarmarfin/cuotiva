import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/collections/data/collections_repository.dart';
import '../../features/contacts/data/contacts_repository.dart';
import '../../features/installments/data/installments_repository.dart';
import '../../features/payments/data/attachments_repository.dart';
import '../../features/payments/data/payments_repository.dart';
import '../../features/receivables/data/balances_repository.dart';
import '../../features/receivables/data/receivables_repository.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/settlements/data/settlements_repository.dart';
import '../../features/spaces/data/spaces_repository.dart';
import '../backup/backup_service.dart';
import '../database/audit_service.dart';
import '../notifications/notification_service.dart';
import '../notifications/reminder_scheduler.dart';
import '../../features/settings/data/reminders_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../security/crypto_service.dart';
import '../security/db_key_service.dart';
import 'core_providers.dart';

final auditServiceProvider = Provider<AuditService>(
  (ref) => AuditService(
    ref.watch(appDatabaseProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final spacesRepositoryProvider = Provider<SpacesRepository>(
  (ref) => SpacesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final collectionsRepositoryProvider = Provider<CollectionsRepository>(
  (ref) => CollectionsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final installmentsRepositoryProvider = Provider<InstallmentsRepository>(
  (ref) => InstallmentsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

/// Subclave de adjuntos derivada de la clave de la base (obtenida al usarla).
final attachmentCipherProvider = Provider<Future<AeadCipher> Function()>((ref) {
  final keys = ref.watch(dbKeyServiceProvider);
  return () async =>
      AeadCipher.derive(hexToBytes(await keys.getOrCreate()), 'attachments');
});

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>(
  (ref) => AttachmentsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
    // Almacenamiento privado de la app (no visible en la galería).
    getApplicationSupportDirectory,
    // Cifrado en disco con subclave derivada de la clave de la base.
    ref.watch(attachmentCipherProvider),
  ),
);

final receivablesRepositoryProvider = Provider<ReceivablesRepository>(
  (ref) => ReceivablesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
    // Reglas que dependen de lo cobrado usan los pagos confirmados reales.
    collected: ref.watch(paymentsRepositoryProvider).confirmedTotal,
  ),
);

final balancesRepositoryProvider = Provider<BalancesRepository>(
  (ref) => BalancesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

final settlementsRepositoryProvider = Provider<SettlementsRepository>(
  (ref) => SettlementsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(auditServiceProvider),
    ref.watch(uuidProvider),
    ref.watch(clockProvider),
  ),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(attachmentsRepositoryProvider),
  ),
);

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final keys = ref.watch(dbKeyServiceProvider);
  return BackupService(
    paths: await BackupPaths.resolve(),
    attachments: ref.watch(attachmentsRepositoryProvider),
    dbHexKey: keys.getOrCreate,
    attachmentCipher: ref.watch(attachmentCipherProvider),
    schemaVersion: db.schemaVersion,
    clock: ref.watch(clockProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final reminderSinkProvider = Provider<ReminderSink>(
  (_) => LocalNotificationSink(),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final s = ReminderScheduler(
    ref.watch(settingsRepositoryProvider),
    RemindersRepository(ref.watch(appDatabaseProvider)),
    ref.watch(reminderSinkProvider),
    ref.watch(clockProvider),
  );
  ref.onDispose(s.dispose);
  return s;
});
