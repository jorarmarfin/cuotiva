import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/collections/presentation/providers/collections_providers.dart';
import 'package:cuotiva/features/collections/presentation/screens/collection_detail_screen.dart';
import 'package:cuotiva/features/collections/presentation/screens/collections_screen.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
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

  testWidgets('lista de cobros: vacío', (tester) async {
    await tester.pumpWidget(
      _app(const CollectionsScreen(), [
        collectionsProvider.overrideWith((_) => Stream.value([])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Aún no tienes cobros'), findsOneWidget);
  });

  testWidgets('lista de cobros: muestra tipo y terceros', (tester) async {
    await tester.pumpWidget(
      _app(const CollectionsScreen(), [
        collectionsProvider.overrideWith((_) => Stream.value([collection])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Trajes 2027'), findsOneWidget);
    expect(find.textContaining('Fondos de terceros'), findsOneWidget);
  });

  testWidgets('detalle: suma comprometida de obligaciones', (tester) async {
    await tester.pumpWidget(
      _app(const CollectionDetailScreen(collectionId: 'k1'), [
        collectionByIdProvider('k1').overrideWith((_) async => collection),
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
