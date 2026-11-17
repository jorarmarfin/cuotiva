import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricService {
  Future<bool> get isAvailable;
  Future<bool> authenticate(String reason);

  /// Comprueba disponibilidad y pide confirmar. null = todo bien; si no, el
  /// motivo en lenguaje claro para mostrárselo al usuario.
  Future<String?> verifyForActivation(String reason);
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
    } on MissingPluginException {
      return false; // plataforma sin biometría (p. ej. escritorio Linux)
    }
  }

  @override
  Future<String?> verifyForActivation(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return 'Este dispositivo no admite biometría.';
      }
      if ((await _auth.getAvailableBiometrics()).isEmpty) {
        return 'No hay huella ni rostro registrados. Regístralos en los '
            'ajustes del teléfono e inténtalo de nuevo.';
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? null : 'No se confirmó la biometría.';
    } on MissingPluginException {
      return 'La biometría no está disponible en esta plataforma '
          '(en el escritorio no existe; pruébala en el teléfono).';
    } on PlatformException catch (e) {
      return 'Error de biometría (${e.code}). ${e.message ?? ''}'.trim();
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
    } on MissingPluginException {
      return false; // plataforma sin biometría (p. ej. escritorio Linux)
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
