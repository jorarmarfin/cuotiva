import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_service.dart';

/// Preferencias de seguridad (se guardan junto al PIN, en el almacén seguro).
class LockSettings {
  const LockSettings({
    this.biometric = false,
    this.graceSeconds = 30,
    this.secureScreen = false,
  });

  final bool biometric;

  /// Tiempo en segundo plano tolerado antes de volver a pedir el PIN.
  final int graceSeconds;

  /// FLAG_SECURE: bloquea capturas y la vista previa en apps recientes.
  final bool secureScreen;

  static const graceOptions = [0, 30, 60, 300];

  LockSettings copyWith({
    bool? biometric,
    int? graceSeconds,
    bool? secureScreen,
  }) => LockSettings(
    biometric: biometric ?? this.biometric,
    graceSeconds: graceSeconds ?? this.graceSeconds,
    secureScreen: secureScreen ?? this.secureScreen,
  );

  String encode() =>
      '${biometric ? 1 : 0}:$graceSeconds:${secureScreen ? 1 : 0}';

  static LockSettings decode(String? s) {
    final p = s?.split(':');
    if (p == null || p.length != 3) return const LockSettings();
    return LockSettings(
      biometric: p[0] == '1',
      graceSeconds: int.tryParse(p[1]) ?? 30,
      secureScreen: p[2] == '1',
    );
  }
}

abstract interface class LockSettingsStore {
  Future<LockSettings> load();
  Future<void> save(LockSettings s);
}

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);

class SecureLockSettingsStore implements LockSettingsStore {
  const SecureLockSettingsStore();
  static const _key = 'cuotiva_lock_settings';
  @override
  Future<LockSettings> load() async =>
      LockSettings.decode(await _storage.read(key: _key));
  @override
  Future<void> save(LockSettings s) =>
      _storage.write(key: _key, value: s.encode());
}

class SecurePinStore implements PinStore {
  const SecurePinStore();
  static const _key = 'cuotiva_pin';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
