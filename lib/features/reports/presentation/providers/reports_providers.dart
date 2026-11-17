import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../domain/report_models.dart';

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();
  void set(ReportFilter f) => state = f;
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(
      ReportFilterNotifier.new,
    );

/// Se recalcula al cambiar el filtro; `ref.invalidate` al volver de la vista
/// previa no hace falta porque los PDF no modifican datos.
final reportRowsProvider = FutureProvider<List<ObligationRow>>(
  (ref) => ref
      .watch(reportsRepositoryProvider)
      .search(ref.watch(reportFilterProvider)),
);
