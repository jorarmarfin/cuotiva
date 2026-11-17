import 'package:cuotiva/core/providers/core_providers.dart';
import 'package:cuotiva/core/security/app_lock.dart';
import 'package:cuotiva/core/security/biometric_service.dart';
import 'package:cuotiva/core/security/lock_settings.dart';
import 'package:cuotiva/core/security/pin_service.dart';
import 'package:cuotiva/core/widgets/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pin implements PinStore {
  String? v;
  @override
  Future<String?> read() async => v;
  @override
  Future<void> write(String value) async => v = value;
  @override
  Future<void> clear() async => v = null;
}

class _Settings implements LockSettingsStore {
  LockSettings s = const LockSettings();
  @override
  Future<LockSettings> load() async => s;
  @override
  Future<void> save(LockSettings x) async => s = x;
}

class _Bio implements BiometricService {
  _Bio(this.ok);
  final bool ok;
  @override
  Future<bool> get isAvailable async => true;
  @override
  Future<bool> authenticate(String reason) async => ok;
}

void main() {
  var now = DateTime(2026, 11, 17, 10);
  late _Pin pinStore;
  late _Settings settings;

  ProviderContainer make({bool bio = true}) {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        pinServiceProvider.overrideWith(
          (ref) => PinService(
            pinStore,
            () => now,
            iterations: 100,
            useIsolate: false,
          ),
        ),
        lockSettingsStoreProvider.overrideWithValue(settings),
        biometricServiceProvider.overrideWithValue(_Bio(bio)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> loaded(ProviderContainer c) async {
    c.read(appLockProvider);
    while (!c.read(appLockProvider).loaded) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    now = DateTime(2026, 11, 17, 10);
    pinStore = _Pin();
    settings = _Settings();
  });

  test('sin PIN no hay bloqueo', () async {
    final c = make();
    await loaded(c);
    expect(c.read(appLockProvider).locked, isFalse);
    c.read(appLockProvider.notifier)
      ..onBackground()
      ..onResume();
    expect(c.read(appLockProvider).locked, isFalse);
  });

  test(
    'con PIN arranca bloqueado y se desbloquea con el PIN correcto',
    () async {
      await PinService(
        pinStore,
        () => now,
        iterations: 100,
        useIsolate: false,
      ).setPin('1234');
      final c = make();
      await loaded(c);
      final n = c.read(appLockProvider.notifier);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.unlockWithPin('0000'), PinResult.wrong);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.unlockWithPin('1234'), PinResult.ok);
      expect(c.read(appLockProvider).locked, isFalse);
    },
  );

  test('periodo de gracia: dentro no bloquea, fuera sí', () async {
    final c = make();
    await loaded(c);
    final n = c.read(appLockProvider.notifier);
    await n.setPin('1234');
    expect(c.read(appLockProvider).locked, isFalse);

    n.onBackground();
    now = now.add(const Duration(seconds: 10));
    n.onResume();
    expect(c.read(appLockProvider).locked, isFalse);

    n.onBackground();
    now = now.add(const Duration(seconds: 31));
    n.onResume();
    expect(c.read(appLockProvider).locked, isTrue);

    await n.unlockWithPin('1234');
    await n.updateSettings(
      c.read(appLockProvider).settings.copyWith(graceSeconds: 0),
    );
    n.onBackground();
    n.onResume();
    expect(c.read(appLockProvider).locked, isTrue);
  });

  test('la pausa causada por el aviso biométrico no re-bloquea', () async {
    final c = make();
    await loaded(c);
    final n = c.read(appLockProvider.notifier);
    await n.setPin('1234');
    await n.updateSettings(
      c
          .read(appLockProvider)
          .settings
          .copyWith(graceSeconds: 0, biometric: true),
    );
    n.lockNow();
    n.onBackground(); // el prompt pausa la app mientras está bloqueada
    expect(await n.unlockWithBiometric(), isTrue);
    n.onResume();
    expect(c.read(appLockProvider).locked, isFalse);
  });

  test('biometría fallida o desactivada no desbloquea', () async {
    final c = make(bio: false);
    await loaded(c);
    final n = c.read(appLockProvider.notifier);
    await n.setPin('1234');
    await n.updateSettings(
      c.read(appLockProvider).settings.copyWith(biometric: true),
    );
    n.lockNow();
    expect(await n.unlockWithBiometric(), isFalse);
    expect(c.read(appLockProvider).locked, isTrue);
  });

  test('quitar el PIN desactiva biometría y bloqueo', () async {
    final c = make();
    await loaded(c);
    final n = c.read(appLockProvider.notifier);
    await n.setPin('1234');
    await n.updateSettings(
      c.read(appLockProvider).settings.copyWith(biometric: true),
    );
    await n.removePin();
    final s = c.read(appLockProvider);
    expect(s.pinSet, isFalse);
    expect(s.settings.biometric, isFalse);
    expect(await PinService(pinStore, () => now).isSet, isFalse);
  });

  testWidgets('LockScreen: teclado desbloquea con el PIN', (tester) async {
    await PinService(
      pinStore,
      () => now,
      iterations: 100,
      useIsolate: false,
    ).setPin('1234');
    final c = make(bio: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: LockGate(child: Scaffold(body: Text('CONTENIDO'))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.text('Desbloquear'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Ingresa tu PIN'), findsNothing);
    expect(find.text('CONTENIDO'), findsOneWidget);
  });
}
