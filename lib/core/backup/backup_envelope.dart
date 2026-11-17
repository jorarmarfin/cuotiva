import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../security/crypto_service.dart';
import '../security/pin_service.dart' show pbkdf2;

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sobre cifrado del respaldo:
/// `CQBK` | versión(1) | iteraciones(4) | sal(16) | AEAD(zip)
/// La clave sale de la frase de recuperación (PBKDF2-HMAC-SHA256), no del PIN
/// ni del Keystore, así el archivo se puede restaurar en otro dispositivo.
/// La cabecera va como AAD: alterarla invalida el archivo.
class BackupEnvelope {
  static const magic = [0x43, 0x51, 0x42, 0x4B]; // "CQBK"
  static const version = 1;
  static const defaultIterations = 300000;
  static const minPassphraseLength = 12;
  static const _headerLen = 4 + 1 + 4 + 16;

  static void checkPassphrase(String p) {
    if (p.trim().length < minPassphraseLength) {
      throw BackupException(
        'La frase de recuperación debe tener al menos $minPassphraseLength caracteres',
      );
    }
  }

  /// Frase aleatoria legible: 5 grupos de 5 caracteres (≈ 125 bits).
  static String generatePassphrase([Random? random]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin I, O, 0, 1
    final r = random ?? Random.secure();
    return List.generate(
      5,
      (_) =>
          List.generate(5, (_) => alphabet[r.nextInt(alphabet.length)]).join(),
    ).join('-');
  }

  static String _normalize(String p) => p.trim();

  static Future<Uint8List> _key(
    String passphrase,
    List<int> salt,
    int iterations,
    bool useIsolate,
  ) {
    final pw = _normalize(passphrase).codeUnits;
    if (!useIsolate) {
      return Future.value(pbkdf2(pw, salt, iterations: iterations));
    }
    return Isolate.run(() => pbkdf2(pw, salt, iterations: iterations));
  }

  static Future<Uint8List> seal(
    Uint8List zip,
    String passphrase, {
    int iterations = defaultIterations,
    Random? random,
    bool useIsolate = true,
  }) async {
    checkPassphrase(passphrase);
    final r = random ?? Random.secure();
    final salt = [for (var i = 0; i < 16; i++) r.nextInt(256)];
    final header = Uint8List.fromList([
      ...magic,
      version,
      ...(ByteData(4)..setUint32(0, iterations)).buffer.asUint8List(),
      ...salt,
    ]);
    final key = await _key(passphrase, salt, iterations, useIsolate);
    final body = await AeadCipher(key).encrypt(zip, aad: header);
    return Uint8List.fromList([...header, ...body]);
  }

  static Future<Uint8List> open(
    Uint8List data,
    String passphrase, {
    bool useIsolate = true,
  }) async {
    if (data.length < _headerLen + 32 ||
        !List.generate(4, (i) => data[i] == magic[i]).every((e) => e)) {
      throw BackupException('El archivo no es un respaldo de Cuotiva');
    }
    if (data[4] != version) {
      throw BackupException(
        'Versión de respaldo no compatible (${data[4]}). Actualiza la app.',
      );
    }
    final iterations = ByteData.sublistView(data, 5, 9).getUint32(0);
    if (iterations < 1000 || iterations > 5000000) {
      throw BackupException('Respaldo dañado (parámetros inválidos)');
    }
    final header = data.sublist(0, _headerLen);
    final salt = data.sublist(9, 25);
    final key = await _key(passphrase, salt, iterations, useIsolate);
    try {
      return await AeadCipher(key)
          .decrypt(data.sublist(_headerLen), aad: header);
    } on CryptoException {
      throw BackupException(
        'Frase de recuperación incorrecta o archivo alterado',
      );
    }
  }
}
