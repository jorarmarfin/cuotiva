import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock.dart';
import '../security/pin_service.dart';

/// Pantalla de desbloqueo con PIN numérico y biometría opcional.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  var _pin = '';
  String? _error;
  int _waitSeconds = 0;
  Timer? _timer;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshWait();
    if (ref.read(appLockProvider).settings.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshWait() async {
    final left = await ref
        .read(appLockProvider.notifier)
        .lockRemainingSeconds();
    if (!mounted) return;
    setState(() => _waitSeconds = left);
    _timer?.cancel();
    if (left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _waitSeconds = (_waitSeconds - 1).clamp(0, 1 << 30));
        if (_waitSeconds == 0) t.cancel();
      });
    }
  }

  Future<void> _biometric() async {
    await ref.read(appLockProvider.notifier).unlockWithBiometric();
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < PinService.minLength) return;
    setState(() => _busy = true);
    final r = await ref.read(appLockProvider.notifier).unlockWithPin(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = switch (r) {
        PinResult.ok => null,
        PinResult.wrong => 'PIN incorrecto',
        PinResult.locked => 'Demasiados intentos',
        PinResult.notSet => null,
      };
    });
    if (r == PinResult.locked) await _refreshWait();
  }

  void _tap(String d) {
    if (_waitSeconds > 0 || _busy || _pin.length >= PinService.maxLength) {
      return;
    }
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biometric = ref.watch(appLockProvider).settings.biometric;
    Widget key(
      String label, {
      VoidCallback? onTap,
      IconData? icon,
      String? semantics,
    }) => Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 72,
        height: 64,
        child: TextButton(
          onPressed: onTap,
          child: icon != null
              ? Icon(icon, semanticLabel: semantics)
              : Text(label, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: scheme.primary),
                const SizedBox(height: 12),
                const Text(
                  'Ingresa tu PIN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'PIN: ${_pin.length} dígitos ingresados',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _pin.length.clamp(4, 8); i++)
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length ? scheme.primary : null,
                            border: Border.all(color: scheme.outline),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _waitSeconds > 0
                            ? 'Espera $_waitSeconds s para reintentar'
                            : _error ?? '',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
                ),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final d in row) key(d, onTap: () => _tap(d)),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    biometric
                        ? key(
                            '',
                            icon: Icons.fingerprint,
                            onTap: _biometric,
                            semantics: 'Usar biometría',
                          )
                        : key('', onTap: null),
                    key('0', onTap: () => _tap('0')),
                    key(
                      '',
                      icon: Icons.backspace_outlined,
                      semantics: 'Borrar último dígito',
                      onTap: () => setState(() {
                        if (_pin.isNotEmpty) {
                          _pin = _pin.substring(0, _pin.length - 1);
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      _pin.length >= PinService.minLength && _waitSeconds == 0
                      ? _submit
                      : null,
                  child: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Envuelve la app: muestra [LockScreen] encima mientras esté bloqueada y
/// observa el ciclo de vida para el periodo de gracia.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final lock = ref.read(appLockProvider.notifier);
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      lock.onBackground();
    } else if (s == AppLifecycleState.resumed) {
      lock.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    return Stack(
      children: [
        widget.child,
        // Mientras carga la configuración no se muestra contenido financiero.
        if (!lock.loaded)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: const SizedBox.expand(),
          )
        else if (lock.locked)
          const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
