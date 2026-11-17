import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/collections/data/collections_repository.dart';
import '../../features/contacts/data/contacts_repository.dart';
import '../../features/payments/data/payments_repository.dart';
import '../../features/receivables/data/receivables_repository.dart';
import '../../features/spaces/data/spaces_repository.dart';
import '../database/audit_service.dart';
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
