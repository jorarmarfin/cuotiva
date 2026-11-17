import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:cuotiva/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:cuotiva/features/dashboard/presentation/screens/home_screen.dart';
import 'package:cuotiva/features/receivables/data/balances_repository.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/spaces/presentation/providers/spaces_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 11, 17);

  Widget app(List<Override> o) => ProviderScope(
    overrides: o,
    child: const MaterialApp(home: HomeScreen()),
  );

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.pump();
    }
  }

  List<Override> base({
    CollectionTotals? totals,
    List<DueItem> due = const [],
    List<Payment> pays = const [],
  }) => [
    dashboardTotalsProvider.overrideWith(
      (_) => Stream.value(
        totals ??
            const CollectionTotals(
              committedMinor: 1100000,
              collectedMinor: 665000,
              pendingMinor: 435000,
              overdueMinor: 0,
              participants: 12,
            ),
      ),
    ),
    upcomingDueProvider.overrideWith((_) => Stream.value(due)),
    recentPaymentsProvider.overrideWith((_) => Stream.value(pays)),
    activeSpacesProvider.overrideWith((_) => Stream.value([])),
  ];

  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('muestra saldo por cobrar, recaudado y avance reales', (
    tester,
  ) async {
    await tester.pumpWidget(app(base()));
    await settle(tester);
    expect(find.text('S/ 4,350.00'), findsOneWidget);
    expect(find.text('S/ 6,650.00'), findsOneWidget);
    expect(find.textContaining('60.5% recaudado'), findsOneWidget);
    expect(
      find.text('Nada por vencer en los próximos 30 días.'),
      findsOneWidget,
    );
    expect(find.text('Aún no hay abonos registrados.'), findsOneWidget);
  });

  testWidgets('con vencido muestra la tarjeta Vencido', (tester) async {
    await tester.pumpWidget(
      app(
        base(
          totals: const CollectionTotals(
            committedMinor: 30000,
            collectedMinor: 0,
            pendingMinor: 30000,
            overdueMinor: 15000,
            participants: 2,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('S/ 150.00'), findsOneWidget);
  });

  testWidgets('lista vencimientos y pagos recientes', (tester) async {
    final due = [
      DueItem(
        receivableId: 'r1',
        contactId: 'c1',
        collectionId: 'k1',
        dueAt: DateTime(2026, 11, 10),
        remainingMinor: 9000,
        currency: 'PEN',
        overdue: true,
      ),
    ];
    final pay = Payment(
      id: 'p1',
      createdAt: now,
      updatedAt: now,
      receivableId: 'r1',
      amountMinor: 3000,
      currency: 'PEN',
      occurredAt: now,
      method: 'yape',
      status: 'pending_verification',
    );
    await tester.pumpWidget(
      app([
        ...base(due: due, pays: [pay]),
        contactByIdProvider('c1').overrideWith(
          (_) async => Contact(
            id: 'c1',
            createdAt: now,
            updatedAt: now,
            displayName: 'Rosa',
          ),
        ),
      ]),
    );
    await settle(tester);
    expect(find.text('Rosa'), findsOneWidget);
    expect(find.textContaining('Venció el'), findsOneWidget);
    expect(find.text('S/ 90.00'), findsOneWidget);
    expect(find.text('S/ 30.00'), findsOneWidget);
    expect(find.text('Por verificar'), findsOneWidget);
  });

  testWidgets('filtro por espacio: chips Todos + espacios', (tester) async {
    final space = Space(
      id: 's1',
      createdAt: now,
      updatedAt: now,
      name: 'Colegio',
      type: 'school',
      color: 1,
      icon: 'school',
    );
    await tester.pumpWidget(
      app([
        ...base(),
        activeSpacesProvider.overrideWith((_) => Stream.value([space])),
      ]),
    );
    await settle(tester);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Colegio'), findsOneWidget);
  });
}
