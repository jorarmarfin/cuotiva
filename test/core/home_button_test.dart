import 'dart:async';

import 'package:cuotiva/core/widgets/home_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('cierra todas las pantallas abiertas y vuelve al inicio', (
    tester,
  ) async {
    Widget page(String t) => Scaffold(
      appBar: AppBar(title: Text(t), actions: const [HomeButton()]),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => page('Inicio')),
        GoRoute(path: '/a', builder: (_, _) => page('A')),
        GoRoute(path: '/a/b', builder: (_, _) => page('B')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byIcon(Icons.home_outlined), findsNothing); // ya en inicio
    unawaited(router.push('/a'));
    await tester.pumpAndSettle();
    unawaited(router.push('/a/b'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('sin router no muestra nada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeButton())),
    );
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });
}
