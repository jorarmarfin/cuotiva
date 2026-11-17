import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/payments/presentation/providers/payments_providers.dart';
import 'package:cuotiva/features/payments/presentation/screens/payment_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 11, 17);

  Payment pay(String status, {String? voidReason}) => Payment(
    id: 'p1',
    createdAt: now,
    updatedAt: now,
    receivableId: 'r1',
    amountMinor: 4000,
    currency: 'PEN',
    occurredAt: now,
    method: 'yape',
    status: status,
    reference: 'OP-123',
    voidReason: voidReason,
  );

  AuditLog log(String action) => AuditLog(
    id: action,
    createdAt: now,
    updatedAt: now,
    entityType: 'payment',
    entityId: 'p1',
    action: action,
    occurredAt: now,
  );

  Widget app(Payment p, List<AuditLog> logs) => ProviderScope(
    overrides: [
      paymentProvider('p1').overrideWith((_) => Stream.value(p)),
      attachmentsByPaymentProvider('p1').overrideWith((_) => Stream.value([])),
      paymentAuditProvider('p1').overrideWith((_) => Stream.value(logs)),
    ],
    child: const MaterialApp(home: PaymentDetailScreen(paymentId: 'p1')),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('por verificar: ofrece confirmar y rechazar, no anular', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(pay('pending_verification'), [log('register')]),
    );
    await settle(tester);
    expect(find.text('S/ 40.00'), findsOneWidget);
    expect(find.text('Por verificar'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Anular abono'), findsNothing);
    expect(find.textContaining('Referencia: OP-123'), findsOneWidget);
    expect(find.text('Registrado'), findsOneWidget);
  });

  testWidgets('confirmado: solo permite anular, con historial', (tester) async {
    await tester.pumpWidget(
      app(pay('confirmed'), [log('confirm'), log('register')]),
    );
    await settle(tester);
    expect(find.text('Anular abono'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Confirmado'), findsWidgets);
    expect(find.text('Registrado'), findsOneWidget);
  });

  testWidgets('anular exige motivo (botón Aceptar deshabilitado sin texto)', (
    tester,
  ) async {
    await tester.pumpWidget(app(pay('confirmed'), const []));
    await settle(tester);
    await tester.tap(find.text('Anular abono'));
    await tester.pumpAndSettle();
    final accept = find.widgetWithText(FilledButton, 'Aceptar');
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Error de digitación');
    await tester.pump();
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
  });

  testWidgets('anulado: sin acciones y muestra el motivo', (tester) async {
    await tester.pumpWidget(
      app(pay('voided', voidReason: 'Duplicado'), const []),
    );
    await settle(tester);
    expect(find.textContaining('Motivo: Duplicado'), findsOneWidget);
    expect(find.text('Anular abono'), findsNothing);
    expect(find.text('Confirmar'), findsNothing);
    expect(find.byTooltip('Cámara'), findsNothing);
  });
}
