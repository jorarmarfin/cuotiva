/// Importe monetario exacto: entero en unidad mínima (céntimos) + ISO 4217.
/// Nunca usa `double` para calcular. (CUOTIVA_SPEC §4.1)
class Money implements Comparable<Money> {
  const Money.minor(this.minor, {this.currency = 'PEN'});
  const Money.zero({this.currency = 'PEN'}) : minor = 0;

  final int minor;
  final String currency;

  static const _symbols = {'PEN': 'S/', 'USD': r'US$'};

  /// Interpreta texto como importe positivo con hasta 2 decimales.
  /// Acepta prefijo "S/", espacios y comas de millar: "S/ 1,234.56".
  factory Money.parse(String input, {String currency = 'PEN'}) {
    var s = input.trim();
    if (s.startsWith('S/')) s = s.substring(2).trim();
    s = s.replaceAll(' ', '');
    if (!RegExp(r'^(\d{1,3}(,\d{3})+|\d+)(\.\d{1,2})?$').hasMatch(s)) {
      throw FormatException('Importe inválido', input);
    }
    s = s.replaceAll(',', '');
    final parts = s.split('.');
    final whole = int.parse(parts[0]);
    final frac = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return Money.minor(whole * 100 + frac, currency: currency);
  }

  bool get isZero => minor == 0;
  bool get isPositive => minor > 0;
  bool get isNegative => minor < 0;

  Money operator +(Money o) =>
      Money.minor(minor + _same(o).minor, currency: currency);
  Money operator -(Money o) =>
      Money.minor(minor - _same(o).minor, currency: currency);
  Money operator -() => Money.minor(-minor, currency: currency);
  bool operator <(Money o) => minor < _same(o).minor;
  bool operator <=(Money o) => minor <= _same(o).minor;
  bool operator >(Money o) => minor > _same(o).minor;
  bool operator >=(Money o) => minor >= _same(o).minor;

  /// Reparte en [parts] partes; el resto va a las primeras (suma exacta).
  List<Money> split(int parts) {
    if (parts <= 0) throw ArgumentError.value(parts, 'parts', 'debe ser > 0');
    final base = minor ~/ parts;
    final rest = minor % parts;
    return [
      for (var i = 0; i < parts; i++)
        Money.minor(base + (i < rest ? 1 : 0), currency: currency),
    ];
  }

  String format() {
    final abs = minor.abs();
    final whole = (abs ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final frac = (abs % 100).toString().padLeft(2, '0');
    final symbol = _symbols[currency] ?? currency;
    return '${minor < 0 ? '-' : ''}$symbol $whole.$frac';
  }

  Money _same(Money o) {
    if (o.currency != currency) {
      throw CurrencyMismatchException(currency, o.currency);
    }
    return o;
  }

  @override
  int compareTo(Money other) => minor.compareTo(_same(other).minor);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}

class CurrencyMismatchException implements Exception {
  CurrencyMismatchException(this.a, this.b);
  final String a;
  final String b;
  @override
  String toString() => 'No se pueden mezclar monedas: $a vs $b';
}
