import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricService {
  Future<bool> get isAvailable;
  Future<bool> authenticate(String reason);
}

class LocalBiometricService implements BiometricService {
  LocalBiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

/// Bloqueo de capturas/recientes (FLAG_SECURE) vía MethodChannel nativo.
class ScreenSecurity {
  static const _channel = MethodChannel('com.luisitomayta.cuotiva/security');
  static Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // Plataformas sin implementación nativa (tests/escritorio).
    }
  }
}
