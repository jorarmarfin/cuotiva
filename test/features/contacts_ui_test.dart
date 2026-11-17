import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/contacts/presentation/providers/contacts_providers.dart';
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
