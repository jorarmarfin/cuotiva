import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clave de la base de datos: 32 bytes aleatorios guardados en el almacén
/// seguro del sistema (Android Keystore). Nunca se deriva del PIN, así que
/// cambiar el PIN no obliga a recifrar la base (ADR 0004).
abstract interface class DbKeyStore {
  Future<String?> read();
  Future<void> write(String hexKey);
}

class SecureDbKeyStore implements DbKeyStore {
  const SecureDbKeyStore([
    // resetOnError: false — si el Keystore falla, NO se borra la clave
    // (borrarla dejaría la base cifrada irrecuperable).
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  ]);
  static const _name = 'cuotiva_db_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _name);
  @override
  Future<void> write(String hexKey) =>
      _storage.write(key: _name, value: hexKey);
}

class DbKeyService {
  DbKeyService(this._store, {Random? random})
    : _random = random ?? Random.secure();

  final DbKeyStore _store;
  final Random _random;

  /// Devuelve la clave (64 hex); la crea en el primer uso.
  Future<String> getOrCreate() async {
    final existing = await _store.read();
    if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
      return existing;
    }
    final hex = [
      for (var i = 0; i < 32; i++)
        _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _store.write(hex);
    return hex;
  }
}
