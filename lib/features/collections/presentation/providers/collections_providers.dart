import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../receivables/domain/balance_calculator.dart';

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
  final space = ref.watch(collectionSpaceFilterProvider);
  return ref
      .watch(collectionsRepositoryProvider)
      .watchActive(query: q, spaceId: space);
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

final collectionTotalsProvider = StreamProvider<Map<String, CollectionTotals>>(
  (ref) => ref.watch(balancesRepositoryProvider).watchTotalsByCollection(),
);

enum CollectionStatusFilter { all, withBalance, overdue, paid }

class CollectionStatusFilterNotifier extends Notifier<CollectionStatusFilter> {
  @override
  CollectionStatusFilter build() => CollectionStatusFilter.all;
  // ignore: use_setters_to_change_properties
  void set(CollectionStatusFilter f) => state = f;
}

final collectionStatusFilterProvider =
    NotifierProvider<CollectionStatusFilterNotifier, CollectionStatusFilter>(
      CollectionStatusFilterNotifier.new,
    );

class CollectionSpaceFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? id) => state = id;
}

final collectionSpaceFilterProvider =
    NotifierProvider<CollectionSpaceFilterNotifier, String?>(
      CollectionSpaceFilterNotifier.new,
    );

/// Aplica el filtro de estado sobre los totales del cobro (puro y testeable).
bool matchesStatusFilter(CollectionStatusFilter f, CollectionTotals? t) {
  if (f == CollectionStatusFilter.all) return true;
  if (t == null) return false;
  return switch (f) {
    CollectionStatusFilter.all => true,
    CollectionStatusFilter.withBalance => t.pendingMinor > 0,
    CollectionStatusFilter.overdue => t.overdueMinor > 0,
    CollectionStatusFilter.paid => t.committedMinor > 0 && t.pendingMinor == 0,
  };
}
