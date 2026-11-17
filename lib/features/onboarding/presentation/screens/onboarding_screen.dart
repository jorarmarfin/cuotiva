import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/security/app_lock.dart';
import '../../../../core/security/pin_service.dart';
import '../../../spaces/domain/space_presets.dart';
import '../providers/onboarding_providers.dart';

/// Primer uso: qué hace la app y cómo protege los datos, PIN y biometría
/// (opcionales) y el primer espacio.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _name = TextEditingController();
  var _step = 0;
  var _typeKey = 'business';
  String? _pinError;
  var _busy = false;

  static const _steps = 4;

  @override
  void dispose() {
    _page.dispose();
    _pin.dispose();
    _pin2.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int to) {
    setState(() => _step = to);
    _page.animateToPage(
      to,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _savePin() async {
    if (_pin.text.isEmpty && _pin2.text.isEmpty) return _go(3); // omitir
    if (!PinService.isValidFormat(_pin.text)) {
      setState(
        () => _pinError =
            'Entre ${PinService.minLength} y ${PinService.maxLength} dígitos',
      );
      return;
    }
    if (_pin.text != _pin2.text) {
      setState(() => _pinError = 'Los PIN no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _pinError = null;
    });
    await ref.read(appLockProvider.notifier).setPin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    _go(2);
  }

  Future<void> _toggleBiometric(bool on) async {
    final ctrl = ref.read(appLockProvider.notifier);
    final s = ref.read(appLockProvider).settings;
    if (on) {
      final bio = ref.read(biometricServiceProvider);
      if (!await bio.isAvailable ||
          !await bio.authenticate('Confirma para activar la biometría')) {
        return;
      }
    }
    await ctrl.updateSettings(s.copyWith(biometric: on));
  }

  Future<void> _finish({required bool createSpace}) async {
    setState(() => _busy = true);
    final name = _name.text.trim();
    if (createSpace && name.isNotEmpty) {
      final t = spaceTypes.firstWhere((x) => x.key == _typeKey);
      await ref
          .read(spacesRepositoryProvider)
          .create(name: name, color: t.color, type: t.key, icon: t.icon);
    }
    await completeOnboarding(ref);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lock = ref.watch(appLockProvider);

    Widget page({
      required IconData icon,
      required String title,
      required String body,
      List<Widget> children = const [],
    }) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Icon(icon, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / _steps),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  page(
                    icon: Icons.lock_person_outlined,
                    title: 'Tus cobros, solo tuyos',
                    body:
                        'Cuotiva guarda todo en este teléfono, sin cuenta ni '
                        'servidores. La base de datos y los comprobantes van '
                        'cifrados. Para no perder nada si cambias de teléfono, '
                        'crea respaldos cifrados desde Ajustes: sin tu frase de '
                        'recuperación nadie (ni nosotros) puede abrirlos.',
                  ),
                  page(
                    icon: Icons.pin_outlined,
                    title: 'Protege el acceso con un PIN',
                    body:
                        'Es opcional pero recomendado. Se pedirá al abrir la '
                        'app y al volver de segundo plano. Déjalo vacío para omitir.',
                    children: [
                      TextField(
                        controller: _pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: PinService.maxLength,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          counterText: '',
                        ),
                      ),
                      TextField(
                        controller: _pin2,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: PinService.maxLength,
                        decoration: InputDecoration(
                          labelText: 'Repite el PIN',
                          counterText: '',
                          errorText: _pinError,
                        ),
                      ),
                    ],
                  ),
                  page(
                    icon: Icons.fingerprint,
                    title: 'Desbloquear con biometría',
                    body: lock.pinSet
                        ? 'Usa tu huella o rostro en lugar de escribir el PIN. '
                              'El PIN seguirá disponible.'
                        : 'Necesitas un PIN para usar la biometría. Puedes '
                              'configurarlo luego en Ajustes.',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activar biometría'),
                        value: lock.settings.biometric,
                        onChanged: lock.pinSet ? _toggleBiometric : null,
                      ),
                    ],
                  ),
                  page(
                    icon: Icons.folder_special_outlined,
                    title: 'Crea tu primer espacio',
                    body:
                        'Un espacio agrupa tus cobros: Familia, Negocio, '
                        'Colegio… Puedes crear más después.',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in spaceTypes)
                            ChoiceChip(
                              avatar: Icon(spaceIconData(t.icon), size: 18),
                              label: Text(t.label),
                              selected: _typeKey == t.key,
                              onSelected: (_) => setState(() {
                                _typeKey = t.key;
                                if (_name.text.isEmpty) _name.text = t.label;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del espacio',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  if (_step > 0 && _step < 3)
                    TextButton(
                      onPressed: _busy ? null : () => _go(_step - 1),
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  if (_step == 3)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _finish(createSpace: false),
                      child: const Text('Omitir'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : switch (_step) {
                            0 => () => _go(1),
                            1 => _savePin,
                            2 => () => _go(3),
                            _ => () => _finish(createSpace: true),
                          },
                    child: Text(_step == 3 ? 'Empezar' : 'Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra el onboarding encima de la app hasta completarlo.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingDoneProvider);
    return Stack(
      children: [
        child,
        if (done.asData?.value == false)
          const Positioned.fill(child: OnboardingScreen()),
      ],
    );
  }
}
