import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'biometric_service.dart';
import 'lock_settings.dart';
import 'pin_service.dart';

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(const SecurePinStore(), ref.watch(clockProvider)),
);
final lockSettingsStoreProvider = Provider<LockSettingsStore>(
  (_) => const SecureLockSettingsStore(),
);
final biometricServiceProvider = Provider<BiometricService>(
  (_) => LocalBiometricService(),
);

class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.pinSet = false,
    this.locked = false,
    this.settings = const LockSettings(),
  });
  final bool loaded;
  final bool pinSet;
  final bool locked;
  final LockSettings settings;

  AppLockState copyWith({
    bool? loaded,
    bool? pinSet,
    bool? locked,
    LockSettings? settings,
  }) => AppLockState(
    loaded: loaded ?? this.loaded,
    pinSet: pinSet ?? this.pinSet,
    locked: locked ?? this.locked,
    settings: settings ?? this.settings,
  );
}

/// Estado de bloqueo: arranca bloqueado si hay PIN; al volver de segundo
/// plano vuelve a bloquear pasado el periodo de gracia.
class AppLockController extends Notifier<AppLockState> {
  DateTime? _backgroundAt;

  @override
  AppLockState build() {
    _load();
    return const AppLockState();
  }

  PinService get _pin => ref.read(pinServiceProvider);
  LockSettingsStore get _store => ref.read(lockSettingsStoreProvider);

  Future<void> _load() async {
    final LockSettings settings;
    final bool set;
    try {
      settings = await _store.load();
      set = await _pin.isSet;
    } on MissingPluginException {
      // Sin almacén seguro nativo (tests/escritorio): sin bloqueo.
      state = const AppLockState(loaded: true);
      return;
    }
    state = AppLockState(
      loaded: true,
      pinSet: set,
      locked: set,
      settings: settings,
    );
    await ScreenSecurity.setSecure(settings.secureScreen);
  }

  Future<PinResult> unlockWithPin(String pin) async {
    final r = await _pin.verify(pin);
    if (r == PinResult.ok) state = state.copyWith(locked: false);
    return r;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.settings.biometric) return false;
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Desbloquea Cuotiva');
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  Future<int> lockRemainingSeconds() => _pin.lockRemainingSeconds();

  Future<void> setPin(String pin) async {
    await _pin.setPin(pin);
    state = state.copyWith(pinSet: true, locked: false);
  }

  /// Quita el PIN (y la biometría, que depende de él).
  Future<void> removePin() async {
    await _pin.removePin();
    final s = state.settings.copyWith(biometric: false);
    await _store.save(s);
    state = state.copyWith(pinSet: false, locked: false, settings: s);
  }

  Future<void> updateSettings(LockSettings s) async {
    await _store.save(s);
    state = state.copyWith(settings: s);
    await ScreenSecurity.setSecure(s.secureScreen);
  }

  void lockNow() {
    if (state.pinSet) state = state.copyWith(locked: true);
  }

  void onBackground() {
    // El aviso biométrico del sistema también pausa la app: no cuenta.
    if (state.locked) return;
    _backgroundAt = ref.read(clockProvider)();
  }

  void onResume() {
    final at = _backgroundAt;
    _backgroundAt = null;
    if (!state.pinSet || state.locked || at == null) return;
    final away = ref.read(clockProvider)().difference(at).inSeconds;
    if (away >= state.settings.graceSeconds) lockNow();
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
