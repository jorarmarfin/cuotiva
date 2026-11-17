import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../receivables/data/balances_repository.dart';
import '../../../receivables/domain/balance_calculator.dart';

/// Espacio seleccionado en el filtro de Inicio (null = todos).
class SelectedSpaceNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void select(String? id) => state = id;
}

final selectedSpaceProvider = NotifierProvider<SelectedSpaceNotifier, String?>(
  SelectedSpaceNotifier.new,
);

final dashboardTotalsProvider = StreamProvider<CollectionTotals>((ref) {
  final space = ref.watch(selectedSpaceProvider);
  return ref.watch(balancesRepositoryProvider).watchTotals(spaceId: space);
});

final upcomingDueProvider = StreamProvider<List<DueItem>>((ref) {
  final space = ref.watch(selectedSpaceProvider);
  return ref.watch(balancesRepositoryProvider).watchUpcomingDue(spaceId: space);
});

final recentPaymentsProvider = StreamProvider<List<Payment>>(
  (ref) => ref.watch(paymentsRepositoryProvider).watchRecent(limit: 5),
);
