import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../domain/balance_calculator.dart';

final receivablesByCollectionProvider =
    StreamProvider.family<List<Receivable>, String>(
      (ref, collectionId) => ref
          .watch(receivablesRepositoryProvider)
          .watchByCollection(collectionId),
    );

/// Todas las personas activas (sin filtro de búsqueda), para pickers.
final allContactsProvider = StreamProvider<List<Contact>>(
  (ref) => ref.watch(contactsRepositoryProvider).watchActive(),
);

final receivablesByContactProvider =
    StreamProvider.family<List<Receivable>, String>(
      (ref, contactId) =>
          ref.watch(receivablesRepositoryProvider).watchByContact(contactId),
    );

final receivableProvider = StreamProvider.family<Receivable?, String>(
  (ref, id) => ref.watch(receivablesRepositoryProvider).watchOne(id),
);

final balanceProvider = StreamProvider.family<Balance?, String>(
  (ref, receivableId) =>
      ref.watch(balancesRepositoryProvider).watchReceivable(receivableId),
);

final collectionBalancesProvider =
    StreamProvider.family<Map<String, Balance>, String>(
      (ref, collectionId) =>
          ref.watch(balancesRepositoryProvider).watchCollection(collectionId),
    );
