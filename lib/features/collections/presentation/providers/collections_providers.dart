import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';

class CollectionQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  // ignore: use_setters_to_change_properties
  void set(String q) => state = q;
}

final collectionQueryProvider =
    NotifierProvider<CollectionQueryNotifier, String>(
      CollectionQueryNotifier.new,
    );

final collectionsProvider = StreamProvider<List<Collection>>((ref) {
  final q = ref.watch(collectionQueryProvider);
  return ref.watch(collectionsRepositoryProvider).watchActive(query: q);
});

final collectionsBySpaceProvider =
    StreamProvider.family<List<Collection>, String>(
      (ref, spaceId) => ref
          .watch(collectionsRepositoryProvider)
          .watchActive(spaceId: spaceId),
    );

final collectionByIdProvider = FutureProvider.family<Collection?, String>(
  (ref, id) => ref.watch(collectionsRepositoryProvider).find(id),
);
