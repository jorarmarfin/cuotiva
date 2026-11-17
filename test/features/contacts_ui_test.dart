import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/collections/presentation/providers/collections_providers.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:cuotiva/features/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:cuotiva/features/receivables/presentation/providers/receivables_providers.dart';
import 'package:cuotiva/features/contacts/presentation/screens/contact_form_screen.dart';
import 'package:cuotiva/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: home),
);

void main() {
  contactDetailTests();
  final now = DateTime(2026, 11, 17);

  testWidgets('lista vacía muestra mensaje', (tester) async {
    await tester.pumpWidget(
      _app(const ContactsScreen(), [
        contactsProvider.overrideWith((_) => Stream.value([])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Aún no tienes personas'), findsOneWidget);
  });

  testWidgets('lista muestra personas con teléfono', (tester) async {
    final c = Contact(
      id: '1',
      createdAt: now,
      updatedAt: now,
      displayName: 'Rosa Pérez',
      phone: '+51987654321',
    );
    await tester.pumpWidget(
      _app(const ContactsScreen(), [
        contactsProvider.overrideWith((_) => Stream.value([c])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Rosa Pérez'), findsOneWidget);
    expect(find.text('+51987654321'), findsOneWidget);
  });

  testWidgets('formulario valida nombre y correo', (tester) async {
    await tester.pumpWidget(_app(const ContactFormScreen(), []));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo (opcional)'),
      'malo',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Ingresa un nombre'), findsOneWidget);
    expect(find.text('Correo inválido'), findsOneWidget);
  });
}

void contactDetailTests() {
  final now = DateTime(2026, 11, 17);
  testWidgets('detalle de persona lista sus obligaciones', (tester) async {
    final c = Contact(
      id: 'c1',
      createdAt: now,
      updatedAt: now,
      displayName: 'María',
    );
    final k = Collection(
      id: 'k1',
      createdAt: now,
      updatedAt: now,
      spaceId: 's',
      title: 'Préstamo',
      kind: 'loan',
      fundsOwnership: 'self',
    );
    final r = Receivable(
      id: 'r1',
      createdAt: now,
      updatedAt: now,
      collectionId: 'k1',
      contactId: 'c1',
      principalMinor: 50000,
      currency: 'PEN',
    );
    await tester.pumpWidget(
      _app(const ContactDetailScreen(contactId: 'c1'), [
        contactByIdProvider('c1').overrideWith((_) async => c),
        receivablesByContactProvider('c1')
            .overrideWith((_) => Stream.value([r])),
        collectionByIdProvider('k1').overrideWith((_) async => k),
      ]),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Préstamo'), findsOneWidget);
    expect(find.text('S/ 500.00'), findsOneWidget);
  });
}
