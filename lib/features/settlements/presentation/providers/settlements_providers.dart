import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../domain/settlement_summary.dart';

final settlementsByCollectionProvider =
    StreamProvider.family<List<Settlement>, String>(
      (ref, collectionId) => ref
          .watch(settlementsRepositoryProvider)
          .watchByCollection(collectionId),
    );

final settlementSummaryProvider =
    StreamProvider.family<SettlementSummary, String>(
      (ref, collectionId) =>
          ref.watch(settlementsRepositoryProvider).watchSummary(collectionId),
    );
