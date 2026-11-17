import 'dart:typed_data';

import 'package:cuotiva/core/security/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);

  test('cifra y descifra; el texto plano no aparece', () async {
    final c = AeadCipher(key);
    final plain = Uint8List.fromList('comprobante-secreto'.codeUnits);
    final enc = await c.encrypt(plain);
    expect(String.fromCharCodes(enc), isNot(contains('secreto')));
    expect(AeadCipher.looksEncrypted(enc), isTrue);
    expect(await c.decrypt(enc), plain);
  });

  test('nonce distinto en cada cifrado', () async {
    final c = AeadCipher(key);
    final a = await c.encrypt([1, 2, 3]);
    final b = await c.encrypt([1, 2, 3]);
    expect(a, isNot(b));
  });

  test('detecta alteración de cualquier byte', () async {
    final c = AeadCipher(key);
    final enc = await c.encrypt(List.filled(64, 7));
    for (final i in [5, 20, enc.length - 1]) {
      final bad = Uint8List.fromList(enc)..[i] ^= 1;
      await expectLater(c.decrypt(bad), throwsA(isA<CryptoException>()));
    }
  });

  test('clave incorrecta y datos que no son del formato', () async {
    final enc = await AeadCipher(key).encrypt([1, 2, 3]);
    await expectLater(
      AeadCipher(List.filled(32, 9)).decrypt(enc),
      throwsA(isA<CryptoException>()),
    );
    await expectLater(
      AeadCipher(key).decrypt(List.filled(40, 0)),
      throwsA(isA<CryptoException>()),
    );
  });

  test('AAD: debe coincidir', () async {
    final c = AeadCipher(key);
    final enc = await c.encrypt([1], aad: [9]);
    expect(await c.decrypt(enc, aad: [9]), [1]);
    await expectLater(
      c.decrypt(enc, aad: [8]),
      throwsA(isA<CryptoException>()),
    );
  });

  test('derive: propósitos distintos dan claves distintas', () async {
    final a = AeadCipher.derive(key, 'attachments');
    final b = AeadCipher.derive(key, 'backup');
    final enc = await a.encrypt([5]);
    await expectLater(b.decrypt(enc), throwsA(isA<CryptoException>()));
    expect(await AeadCipher.derive(key, 'attachments').decrypt(enc), [5]);
  });

  test('longitud de clave inválida', () {
    expect(() => AeadCipher([1, 2, 3]), throwsArgumentError);
  });
}
