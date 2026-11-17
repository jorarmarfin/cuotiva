import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuotiva/app/app.dart';

void main() {
  testWidgets('arranca con la barra inferior', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CuotivaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Cobros'), findsWidgets);
  });
}
