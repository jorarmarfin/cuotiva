import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/features/spaces/presentation/providers/spaces_providers.dart';
import 'package:cuotiva/features/spaces/presentation/screens/space_form_screen.dart';
import 'package:cuotiva/features/spaces/presentation/screens/spaces_screen.dart';
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
      _app(const SpacesScreen(), [
        activeSpacesProvider.overrideWith((_) => Stream.value([])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Aún no tienes espacios'), findsOneWidget);
  });

  testWidgets('lista muestra espacios', (tester) async {
    final space = Space(
      id: '1',
      createdAt: now,
      updatedAt: now,
      name: 'Negocio',
      type: 'business',
      color: 0xFF34D399,
      icon: 'store',
    );
    await tester.pumpWidget(
      _app(const SpacesScreen(), [
        activeSpacesProvider.overrideWith((_) => Stream.value([space])),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Negocio'), findsOneWidget);
  });

  testWidgets('error de carga se muestra', (tester) async {
    await tester.pumpWidget(
      _app(const SpacesScreen(), [
        activeSpacesProvider.overrideWith((_) => Stream.error('boom')),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
  });

  testWidgets('formulario: nombre vacío muestra validación', (tester) async {
    await tester.pumpWidget(_app(const SpaceFormScreen(), []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Ingresa un nombre'), findsOneWidget);
  });

  testWidgets('formulario: elegir tipo rellena el nombre', (tester) async {
    await tester.pumpWidget(_app(const SpaceFormScreen(), []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capilla'));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'Capilla'), findsOneWidget);
  });
}
