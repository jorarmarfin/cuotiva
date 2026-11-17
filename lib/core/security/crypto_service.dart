import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';

class CryptoException implements Exception {
  CryptoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// AES-256-GCM (AEAD). Formato: `CQV1` | nonce(12) | texto cifrado | etiqueta(16).
/// Cualquier alteración del contenido o de la cabecera hace fallar el descifrado.
class AeadCipher {
  AeadCipher(List<int> key) : _key = SecretKey(List<int>.unmodifiable(key)) {
    if (key.length != 32) throw ArgumentError('La clave debe ser de 32 bytes');
  }

  static const magic = [0x43, 0x51, 0x56, 0x31]; // "CQV1"
  static const _nonceLen = 12;
  static const _macLen = 16;
  static final _algo = AesGcm.with256bits();

  final SecretKey _key;

  /// Subclave independiente por propósito (HMAC-SHA256 con la clave maestra).
  static AeadCipher derive(List<int> master, String purpose) => AeadCipher(
    c.Hmac(c.sha256, master).convert('cuotiva:$purpose:v1'.codeUnits).bytes,
  );

  Future<Uint8List> encrypt(List<int> plain, {List<int> aad = const []}) async {
    final box = await _algo.encrypt(plain, secretKey: _key, aad: aad);
    return Uint8List.fromList([
      ...magic,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> decrypt(List<int> data, {List<int> aad = const []}) async {
    if (data.length < magic.length + _nonceLen + _macLen || !_hasMagic(data)) {
      throw CryptoException('Datos cifrados inválidos');
    }
    final nonce = data.sublist(4, 4 + _nonceLen);
    final mac = data.sublist(data.length - _macLen);
    final body = data.sublist(4 + _nonceLen, data.length - _macLen);
    try {
      final plain = await _algo.decrypt(
        SecretBox(body, nonce: nonce, mac: Mac(mac)),
        secretKey: _key,
        aad: aad,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw CryptoException('Clave incorrecta o datos alterados');
    }
  }

  static bool _hasMagic(List<int> d) {
    for (var i = 0; i < magic.length; i++) {
      if (d[i] != magic[i]) return false;
    }
    return true;
  }

  static bool looksEncrypted(List<int> d) => d.length >= 4 && _hasMagic(d);
}
