import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/collections/presentation/providers/collections_providers.dart';
import 'package:cuotiva/features/collections/presentation/screens/collection_detail_screen.dart';
import 'package:cuotiva/features/collections/presentation/screens/collections_screen.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/settlements/domain/settlement_summary.dart';
import 'package:cuotiva/features/settlements/presentation/providers/settlements_providers.dart';
import 'package:cuotiva/features/spaces/presentation/providers/spaces_providers.dart';
import 'package:cuotiva/features/receivables/presentation/providers/receivables_providers.dart';
import 'package:cuotiva/features/receivables/presentation/screens/assign_receivables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: home),
);

void main() {
  final now = DateTime(2026, 11, 17);
  final collection = Collection(
    id: 'k1',
    createdAt: now,
    updatedAt: now,
    spaceId: 's1',
    title: 'Trajes 2027',
    kind: 'fundraising',
    fundsOwnership: 'third_party',
  );
  Receivable rec(String id, String contact, int minor) => Receivable(
    id: id,
    createdAt: now,
    updatedAt: now,
    collectionId: 'k1',
    contactId: contact,
    principalMinor: minor,
    currency: 'PEN',
  );
  Contact person(String id, String name) =>
      Contact(id: id, createdAt: now, updatedAt: now, displayName: name);

  setUpAll(() => initializeDateFormatting('es'));

  List<Override> listOverrides(
    List<Collection> items,
    Map<String, CollectionTotals> totals, {
    List<Space> spaces = const [],
  }) => [
    collectionsProvider.overrideWith((_) => Stream.value(items)),
    collectionTotalsProvider.overrideWith((_) => Stream.value(totals)),
    activeSpacesProvider.overrideWith((_) => Stream.value(spaces)),
  ];

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
  }

  testWidgets('lista de cobros: vacío', (tester) async {
    await tester.pumpWidget(
      _app(const CollectionsScreen(), listOverrides([], {})),
    );
    await settle(tester);
    expect(find.textContaining('Aún no tienes cobros'), findsOneWidget);
  });

  testWidgets('lista de cobros: espacio, saldo pendiente y terceros', (
    tester,
  ) async {
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
      _app(
        const CollectionsScreen(),
        listOverrides(
          [collection],
          {
            'k1': const CollectionTotals(
              committedMinor: 300000,
              collectedMinor: 100000,
              pendingMinor: 200000,
              overdueMinor: 0,
              participants: 2,
            ),
          },
          spaces: [space],
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Trajes 2027'), findsOneWidget);
    expect(
      find.textContaining('Colegio · Recaudación · Fondos de terceros'),
      findsOneWidget,
    );
    expect(find.text('S/ 2,000.00'), findsOneWidget);
    expect(find.text('pendiente'), findsOneWidget);
  });

  testWidgets('filtro Vencidos oculta cobros sin deuda vencida', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CollectionsScreen(),
        listOverrides(
          [collection],
          {
            'k1': const CollectionTotals(
              committedMinor: 300000,
              collectedMinor: 0,
              pendingMinor: 300000,
              overdueMinor: 0,
              participants: 2,
            ),
          },
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Trajes 2027'), findsOneWidget);
    await tester.tap(find.text('Vencidos'));
    await settle(tester);
    expect(find.text('Trajes 2027'), findsNothing);
    expect(find.text('Sin resultados con estos filtros.'), findsOneWidget);
  });

  test('matchesStatusFilter', () {
    const pending = CollectionTotals(
      committedMinor: 100,
      collectedMinor: 0,
      pendingMinor: 100,
      overdueMinor: 0,
      participants: 1,
    );
    const overdue = CollectionTotals(
      committedMinor: 100,
      collectedMinor: 0,
      pendingMinor: 100,
      overdueMinor: 100,
      participants: 1,
    );
    const paid = CollectionTotals(
      committedMinor: 100,
      collectedMinor: 100,
      pendingMinor: 0,
      overdueMinor: 0,
      participants: 1,
    );
    const empty = CollectionTotals(
      committedMinor: 0,
      collectedMinor: 0,
      pendingMinor: 0,
      overdueMinor: 0,
      participants: 0,
    );
    expect(matchesStatusFilter(CollectionStatusFilter.all, null), isTrue);
    expect(
      matchesStatusFilter(CollectionStatusFilter.withBalance, pending),
      isTrue,
    );
    expect(
      matchesStatusFilter(CollectionStatusFilter.withBalance, paid),
      isFalse,
    );
    expect(
      matchesStatusFilter(CollectionStatusFilter.overdue, overdue),
      isTrue,
    );
    expect(
      matchesStatusFilter(CollectionStatusFilter.overdue, pending),
      isFalse,
    );
    expect(matchesStatusFilter(CollectionStatusFilter.paid, paid), isTrue);
    expect(
      matchesStatusFilter(CollectionStatusFilter.paid, empty),
      isFalse,
      reason: 'sin obligaciones no es "pagado"',
    );
    expect(matchesStatusFilter(CollectionStatusFilter.paid, null), isFalse);
  });

  testWidgets('detalle: suma comprometida de obligaciones', (tester) async {
    await tester.pumpWidget(
      _app(const CollectionDetailScreen(collectionId: 'k1'), [
        collectionByIdProvider('k1').overrideWith((_) async => collection),
        settlementSummaryProvider('k1').overrideWith(
          (_) => Stream.value(
            const SettlementSummary(
              collectedMinor: 60000,
              deliveredMinor: 50000,
            ),
          ),
        ),
        receivablesByCollectionProvider('k1').overrideWith(
          (_) => Stream.value([rec('r1', 'c1', 15000), rec('r2', 'c2', 15000)]),
        ),
        collectionBalancesProvider('k1').overrideWith(
          (_) => Stream.value({
            'r1': BalanceCalculator.receivable(
              principalMinor: 15000,
              payments: const [
                PaymentLine(amountMinor: 5000, status: 'confirmed'),
              ],
              now: now,
            ),
            'r2': BalanceCalculator.receivable(
              principalMinor: 15000,
              payments: const [],
              now: now,
            ),
          }),
        ),
        contactByIdProvider('c1')
            .overrideWith((_) async => person('c1', 'Ana')),
        contactByIdProvider('c2')
            .overrideWith((_) async => person('c2', 'Beto')),
      ]),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('S/ 300.00'), findsOneWidget);
    expect(find.text('S/ 50.00'), findsOneWidget); // recaudado
    expect(find.textContaining('16.7% recaudado'), findsOneWidget);
    expect(find.text('Abonado'), findsOneWidget);
    expect(find.text('S/ 50.00'), findsOneWidget); // recaudado
    expect(find.textContaining('16.7% recaudado'), findsOneWidget);
    expect(find.text('Abonado'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.textContaining('2 participante'), findsOneWidget);
    // Cobro de terceros: bloque recaudado / entregado / por entregar.
    expect(find.text('Por entregar'), findsOneWidget);
    expect(find.text('S/ 100.00'), findsOneWidget);
  });

  testWidgets('asignar: valida importe y selección', (tester) async {
    await tester.pumpWidget(
      _app(const AssignReceivablesScreen(collectionId: 'k1'), [
        allContactsProvider.overrideWith(
          (_) => Stream.value([person('c1', 'Ana')]),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.textContaining('Asignar a'));
    await tester.pump();
    expect(find.textContaining('Importe inválido'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '150');
    await tester.tap(find.textContaining('Asignar a'));
    await tester.pump();
    expect(find.text('Elige al menos una persona'), findsOneWidget);
  });
}
