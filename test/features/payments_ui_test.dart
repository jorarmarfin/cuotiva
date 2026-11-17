import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/collections/presentation/providers/collections_providers.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:cuotiva/features/payments/presentation/providers/payments_providers.dart';
import 'package:cuotiva/features/payments/presentation/screens/payment_form_screen.dart';
import 'package:cuotiva/features/receivables/domain/balance_calculator.dart';
import 'package:cuotiva/features/receivables/presentation/providers/receivables_providers.dart';
import 'package:cuotiva/features/receivables/presentation/screens/receivable_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: home),
);

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final now = DateTime(2026, 11, 17);
  final receivable = Receivable(
    id: 'r1',
    createdAt: now,
    updatedAt: now,
    collectionId: 'k1',
    contactId: 'c1',
    principalMinor: 12000,
    currency: 'PEN',
  );
  final balance = BalanceCalculator.receivable(
    principalMinor: 12000,
    payments: const [
      PaymentLine(amountMinor: 3000, status: 'confirmed'),
      PaymentLine(amountMinor: 4000, status: 'pending_verification'),
    ],
    now: now,
  );
  Payment pay(String id, int amount, String status) => Payment(
    id: id,
    createdAt: now,
    updatedAt: now,
    receivableId: 'r1',
    amountMinor: amount,
    currency: 'PEN',
    occurredAt: now,
    method: 'yape',
    status: status,
  );

  setUpAll(() => initializeDateFormatting('es'));

  List<Override> overrides() => [
    receivableProvider('r1').overrideWith((_) => Stream.value(receivable)),
    balanceProvider('r1').overrideWith((_) => Stream.value(balance)),
    contactByIdProvider('c1').overrideWith(
      (_) async => Contact(
        id: 'c1',
        createdAt: now,
        updatedAt: now,
        displayName: 'Rosa Pérez',
      ),
    ),
    collectionByIdProvider('k1').overrideWith(
      (_) async => Collection(
        id: 'k1',
        createdAt: now,
        updatedAt: now,
        spaceId: 's',
        title: 'Buzos',
        kind: 'credit_sale',
        fundsOwnership: 'self',
      ),
    ),
    installmentPlanProvider('r1').overrideWith((_) => Stream.value([])),
    paymentsByReceivableProvider('r1').overrideWith(
      (_) => Stream.value([
        pay('p1', 3000, 'confirmed'),
        pay('p2', 4000, 'pending_verification'),
      ]),
    ),
  ];

  testWidgets('detalle de obligación: saldo, por verificar y abonos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ReceivableDetailScreen(receivableId: 'r1'), overrides()),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Rosa Pérez'), findsOneWidget);
    expect(
      find.text('S/ 90.00'),
      findsOneWidget,
    ); // saldo: el pendiente no descuenta
    expect(find.textContaining('S/ 40.00 por verificar'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('Por verificar'), findsOneWidget);
    expect(find.text('Registrar abono'), findsOneWidget);
    expect(find.textContaining('Pago libre'), findsOneWidget);
  });

  testWidgets('formulario de abono: precarga el saldo y rechaza exceso', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(
      _app(const PaymentFormScreen(receivableId: 'r1'), overrides()),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.widgetWithText(TextFormField, '90.00'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '90.00'), '200');
    await tester.tap(find.text('Guardar abono'));
    await tester.pump();
    expect(find.textContaining('Excede el saldo'), findsOneWidget);
  });

  testWidgets('formulario de abono: Yape queda por verificar por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PaymentFormScreen(receivableId: 'r1'), overrides()),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(
      find.textContaining('Descuenta del saldo de inmediato'),
      findsOneWidget,
    );
    await tester.tap(find.text('Yape'));
    await tester.pump();
    expect(
      find.textContaining('no confirma el pago por sí sola'),
      findsOneWidget,
    );
  });

  testWidgets('formulario de abono: importe inválido', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      _app(const PaymentFormScreen(receivableId: 'r1'), overrides()),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    await tester.enterText(find.widgetWithText(TextFormField, '90.00'), 'abc');
    await tester.tap(find.text('Guardar abono'));
    await tester.pump();
    expect(find.textContaining('Importe inválido'), findsOneWidget);
  });
}
