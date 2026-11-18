import 'package:cuotiva/core/utils/slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slugify quita tildes y símbolos', () {
    expect(slugify('Trajes 2027 · Ñandú'), 'trajes-2027-nandu');
    expect(slugify('  ¡Colecta!  '), 'colecta');
    expect(slugify('***'), '');
  });

  test('slugify recorta sin dejar guion final', () {
    expect(slugify('abc def ghi', maxLength: 4), 'abc');
  });

  test('reportFileName omite partes vacías', () {
    expect(
      reportFileName('estado-de-cuenta', ['Trajes 2027', 'Rosa Pérez']),
      'estado-de-cuenta_trajes-2027_rosa-perez',
    );
    expect(reportFileName('reporte-de-cobro', ['***']), 'reporte-de-cobro');
  });
}
