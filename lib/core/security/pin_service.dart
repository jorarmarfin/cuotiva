import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (RFC 8018) en Dart puro.
Uint8List pbkdf2(
  List<int> password,
  List<int> salt, {
  required int iterations,
  int length = 32,
}) {
  final prf = Hmac(sha256, password);
  final blocks = (length + 31) ~/ 32;
  final out = BytesBuilder();
  for (var i = 1; i <= blocks; i++) {
    var u = prf.convert([
      ...salt,
      i >> 24 & 255,
      i >> 16 & 255,
      i >> 8 & 255,
      i & 255,
    ]).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = prf.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}

/// Registro persistido del PIN (nunca el PIN en claro).
class PinRecord {
  const PinRecord({
    required this.saltHex,
    required this.hashHex,
    required this.iterations,
    this.failedAttempts = 0,
    this.lockedUntilMs = 0,
  });

  final String saltHex;
  final String hashHex;
  final int iterations;
  final int failedAttempts;

  /// Epoch ms hasta el que no se admiten intentos (0 = sin bloqueo).
  final int lockedUntilMs;

  PinRecord copyWith({int? failedAttempts, int? lockedUntilMs}) => PinRecord(
    saltHex: saltHex,
    hashHex: hashHex,
    iterations: iterations,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntilMs: lockedUntilMs ?? this.lockedUntilMs,
  );

  String encode() =>
      '$saltHex:$hashHex:$iterations:$failedAttempts:$lockedUntilMs';

  static PinRecord? decode(String? s) {
    if (s == null) return null;
    final p = s.split(':');
    if (p.length != 5) return null;
    final it = int.tryParse(p[2]);
    final fa = int.tryParse(p[3]);
    final lu = int.tryParse(p[4]);
    if (it == null || fa == null || lu == null) return null;
    return PinRecord(
      saltHex: p[0],
      hashHex: p[1],
      iterations: it,
      failedAttempts: fa,
      lockedUntilMs: lu,
    );
  }
}

abstract interface class PinStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

enum PinResult { ok, wrong, locked, notSet }

class PinException implements Exception {
  PinException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// PIN de acceso: KDF (PBKDF2) con sal aleatoria y bloqueo escalonado tras
/// intentos fallidos. El PIN protege el acceso a la app; la clave de la base
/// es independiente (ADR 0004).
class PinService {
  PinService(
    this._store,
    this._clock, {
    this.iterations = 150000,
    Random? random,
    this.useIsolate = true,
  }) : _random = random ?? Random.secure();

  static const minLength = 4;
  static const maxLength = 8;

  final PinStore _store;
  final DateTime Function() _clock;
  final int iterations;
  final Random _random;
  final bool useIsolate;

  Future<Uint8List> _derive(String pin, List<int> salt, int iters) {
    final bytes = pin.codeUnits;
    if (!useIsolate) {
      return Future.value(pbkdf2(bytes, salt, iterations: iters));
    }
    return Isolate.run(() => pbkdf2(bytes, salt, iterations: iters));
  }

  static String _hex(List<int> b) =>
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  static List<int> _unhex(String h) => [
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ];

  static bool isValidFormat(String pin) =>
      RegExp('^\\d{$minLength,$maxLength}\$').hasMatch(pin);

  Future<bool> get isSet async => PinRecord.decode(await _store.read()) != null;

  Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw PinException(
        'El PIN debe tener entre $minLength y $maxLength dígitos',
      );
    }
    final salt = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
    final hash = await _derive(pin, salt, iterations);
    await _store.write(
      PinRecord(
        saltHex: _hex(salt),
        hashHex: _hex(hash),
        iterations: iterations,
      ).encode(),
    );
  }

  Future<void> removePin() => _store.clear();

  /// Segundos de espera restantes (0 si se puede intentar).
  Future<int> lockRemainingSeconds() async {
    final r = PinRecord.decode(await _store.read());
    if (r == null) return 0;
    final left = r.lockedUntilMs - _clock().millisecondsSinceEpoch;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  /// Espera tras N fallos acumulados: 5→30 s, 6→1 min, 7→5 min, 8+→15 min.
  static Duration lockFor(int failed) => switch (failed) {
    < 5 => Duration.zero,
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    _ => const Duration(minutes: 15),
  };

  Future<PinResult> verify(String pin) async {
    final r = PinRecord.decode(await _store.read());
    if (r == null) return PinResult.notSet;
    final now = _clock().millisecondsSinceEpoch;
    if (r.lockedUntilMs > now) return PinResult.locked;

    final hash = await _derive(pin, _unhex(r.saltHex), r.iterations);
    if (_constantTimeEquals(_hex(hash), r.hashHex)) {
      if (r.failedAttempts != 0 || r.lockedUntilMs != 0) {
        await _store.write(
          r.copyWith(failedAttempts: 0, lockedUntilMs: 0).encode(),
        );
      }
      return PinResult.ok;
    }
    final failed = r.failedAttempts + 1;
    final wait = lockFor(failed);
    await _store.write(
      r
          .copyWith(
            failedAttempts: failed,
            lockedUntilMs: wait == Duration.zero
                ? 0
                : now + wait.inMilliseconds,
          )
          .encode(),
    );
    return wait == Duration.zero ? PinResult.wrong : PinResult.locked;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
