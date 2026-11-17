import 'package:cuotiva/app/app.dart';
import 'package:cuotiva/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/spaces/presentation/providers/spaces_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('arranca con la barra inferior', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Sin abrir la base real: los datos del Inicio se sobreescriben.
        overrides: [
          dashboardTotalsProvider.overrideWith(
            (_) => Stream.value(
              const CollectionTotals(
                committedMinor: 0,
                collectedMinor: 0,
                pendingMinor: 0,
                overdueMinor: 0,
                participants: 0,
              ),
            ),
          ),
          upcomingDueProvider.overrideWith((_) => Stream.value([])),
          recentPaymentsProvider.overrideWith((_) => Stream.value([])),
          activeSpacesProvider.overrideWith((_) => Stream.value([])),
        ],
        child: const CuotivaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cobros'), findsWidgets);
    expect(find.text('Saldo por cobrar'), findsOneWidget);
  });
}
