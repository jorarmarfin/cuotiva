import 'package:cuotiva/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('suma y resta exactas en céntimos', () {
      const a = Money.minor(1010);
      const b = Money.minor(2020);
      expect((a + b).minor, 3030);
      expect((b - a).minor, 1010);
      // 0.1 + 0.2 con double daría 0.30000000000000004
      expect((Money.parse('0.10') + Money.parse('0.20')).minor, 30);
    });

    test('no mezcla monedas', () {
      expect(
        () => const Money.minor(100) + const Money.minor(100, currency: 'USD'),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('parse acepta formatos válidos', () {
      expect(Money.parse('120').minor, 12000);
      expect(Money.parse('120.5').minor, 12050);
      expect(Money.parse('S/ 1,234.56').minor, 123456);
      expect(Money.parse(' 0.05 ').minor, 5);
    });

    test('parse rechaza formatos inválidos', () {
      for (final s in ['', 'abc', '1.234', '1..2', '-5', '1,2,3x']) {
        expect(() => Money.parse(s), throwsFormatException, reason: s);
      }
    });

    test('format PEN', () {
      expect(const Money.minor(0).format(), 'S/ 0.00');
      expect(const Money.minor(5).format(), 'S/ 0.05');
      expect(const Money.minor(12000).format(), 'S/ 120.00');
      expect(const Money.minor(123456789).format(), 'S/ 1,234,567.89');
      expect(const Money.minor(-4350).format(), '-S/ 43.50');
    });

    test('split reparte el resto sin perder céntimos', () {
      final parts = const Money.minor(10000).split(3);
      expect(parts.map((m) => m.minor), [3334, 3333, 3333]);
      expect(parts.fold<int>(0, (s, m) => s + m.minor), 10000);
    });

    test('split valida partes', () {
      expect(() => const Money.minor(100).split(0), throwsArgumentError);
    });

    test('comparaciones e igualdad', () {
      expect(const Money.minor(100) == const Money.minor(100), isTrue);
      expect(
        const Money.minor(100) == const Money.minor(100, currency: 'USD'),
        isFalse,
      );
      expect(const Money.minor(100) < const Money.minor(200), isTrue);
      expect(const Money.minor(300) > const Money.minor(200), isTrue);
      expect(const Money.minor(100).hashCode, const Money.minor(100).hashCode);
    });

    test('isZero / isPositive / isNegative', () {
      expect(const Money.zero().isZero, isTrue);
      expect(const Money.minor(1).isPositive, isTrue);
      expect(const Money.minor(-1).isNegative, isTrue);
    });
  });
}
