import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';

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
