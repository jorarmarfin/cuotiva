import 'dart:convert';
import 'dart:math';

import 'package:cuotiva/core/security/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mem implements PinStore {
  String? v;
  @override
  Future<String?> read() async => v;
  @override
  Future<void> write(String value) async => v = value;
  @override
  Future<void> clear() async => v = null;
}

String _hex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  var now = DateTime(2026, 11, 17, 10);
  late _Mem store;
  late PinService svc;

  setUp(() {
    now = DateTime(2026, 11, 17, 10);
    store = _Mem();
    svc = PinService(
      store,
      () => now,
      iterations: 1000,
      random: Random(3),
      useIsolate: false,
    );
  });

  test('PBKDF2-HMAC-SHA256: vectores RFC 7914/6070', () {
    // password="password", salt="salt", c=1 y c=2, dkLen=32
    expect(
      _hex(pbkdf2(utf8.encode('password'), utf8.encode('salt'), iterations: 1)),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
    expect(
      _hex(pbkdf2(utf8.encode('password'), utf8.encode('salt'), iterations: 2)),
      'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
    );
  });

  test('guarda sal+hash (no el PIN) y verifica', () async {
    await svc.setPin('1234');
    expect(store.v, isNot(contains('1234')));
    expect(await svc.verify('1234'), PinResult.ok);
    expect(await svc.verify('4321'), PinResult.wrong);
  });

  test('misma clave, sales distintas → registros distintos', () async {
    await svc.setPin('1234');
    final a = store.v;
    await svc.setPin('1234');
    expect(store.v, isNot(a));
  });

  test('formato: 4 a 8 dígitos', () async {
    for (final bad in ['123', '123456789', 'abcd', '12 4']) {
      expect(() => svc.setPin(bad), throwsA(isA<PinException>()), reason: bad);
    }
  });

  test('sin PIN configurado', () async {
    expect(await svc.isSet, isFalse);
    expect(await svc.verify('1234'), PinResult.notSet);
  });

  test('bloqueo escalonado tras 5 fallos y reinicio al acertar', () async {
    await svc.setPin('1234');
    for (var i = 0; i < 4; i++) {
      expect(await svc.verify('0000'), PinResult.wrong);
    }
    expect(await svc.verify('0000'), PinResult.locked);
    expect(await svc.lockRemainingSeconds(), 30);
    // Aun con el PIN correcto, bloqueado.
    expect(await svc.verify('1234'), PinResult.locked);

    now = now.add(const Duration(seconds: 31));
    expect(await svc.lockRemainingSeconds(), 0);
    expect(await svc.verify('1234'), PinResult.ok);
    // Contador reiniciado: vuelve a haber 4 fallos libres.
    expect(await svc.verify('0000'), PinResult.wrong);
  });

  test('los fallos persisten entre instancias (reinicio de app)', () async {
    await svc.setPin('1234');
    for (var i = 0; i < 5; i++) {
      await svc.verify('0000');
    }
    final again = PinService(
      store,
      () => now,
      iterations: 1000,
      useIsolate: false,
    );
    expect(await again.verify('1234'), PinResult.locked);
  });

  test('con isolate da el mismo resultado', () async {
    final s = PinService(store, () => now, iterations: 2000);
    await s.setPin('987654');
    expect(await s.verify('987654'), PinResult.ok);
    expect(await s.verify('987655'), PinResult.wrong);
  });

  test('lockFor escala', () {
    expect(PinService.lockFor(4), Duration.zero);
    expect(PinService.lockFor(6), const Duration(minutes: 1));
    expect(PinService.lockFor(20), const Duration(minutes: 15));
  });
}
