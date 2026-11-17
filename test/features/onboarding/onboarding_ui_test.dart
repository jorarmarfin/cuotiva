import 'package:cuotiva/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpIt(WidgetTester t) => t.pumpWidget(
    const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
  );

  testWidgets('explica la privacidad y avanza al PIN', (t) async {
    await pumpIt(t);
    expect(find.text('Tus cobros, solo tuyos'), findsOneWidget);
    expect(find.textContaining('frase de recuperación'), findsOneWidget);
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    expect(find.text('Protege el acceso con un PIN'), findsOneWidget);
  });

  testWidgets('PIN: valida formato y coincidencia', (t) async {
    await pumpIt(t);
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextField, 'PIN'), '12');
    await t.tap(find.text('Continuar'));
    await t.pump();
    expect(find.textContaining('Entre 4 y 8'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
    await t.enterText(find.widgetWithText(TextField, 'Repite el PIN'), '4321');
    await t.tap(find.text('Continuar'));
    await t.pump();
    expect(find.text('Los PIN no coinciden'), findsOneWidget);
  });

  testWidgets('PIN vacío se omite y llega al primer espacio', (t) async {
    await pumpIt(t);
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continuar')); // sin PIN → omitir
    await t.pumpAndSettle();
    expect(find.text('Crea tu primer espacio'), findsOneWidget);
    await t.tap(find.text('Colegio'));
    await t.pump();
    expect(find.widgetWithText(TextField, 'Colegio'), findsOneWidget);
    expect(find.text('Omitir por ahora'), findsOneWidget);
  });
}
