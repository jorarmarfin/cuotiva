import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/app_lock.dart';
import '../../../../core/security/lock_settings.dart';
import '../../../../core/security/pin_service.dart';
import '../../../../core/update/app_update_service.dart';
import '../widgets/pin_dialogs.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _toast(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  /// Verifica el PIN actual antes de cambiarlo o quitarlo.
  Future<bool> _confirmCurrent(BuildContext context, WidgetRef ref) async {
    final pin = await askPin(context, title: 'PIN actual');
    if (pin == null) return false;
    final r = await ref.read(pinServiceProvider).verify(pin);
    if (r == PinResult.ok) return true;
    if (context.mounted) {
      _toast(
        context,
        r == PinResult.locked
            ? 'Demasiados intentos. Espera un momento.'
            : 'PIN incorrecto',
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final ctrl = ref.read(appLockProvider.notifier);
    final s = lock.settings;

    Future<void> setOrChange() async {
      if (lock.pinSet && !await _confirmCurrent(context, ref)) return;
      if (!context.mounted) return;
      final pin = await askPin(
        context,
        title: lock.pinSet ? 'Nuevo PIN' : 'Crear PIN',
        confirm: true,
      );
      if (pin == null) return;
      await ctrl.setPin(pin);
      if (context.mounted) _toast(context, 'PIN guardado');
    }

    Future<void> remove() async {
      if (!await _confirmCurrent(context, ref)) return;
      await ctrl.removePin();
      if (context.mounted) _toast(context, 'PIN eliminado');
    }

    Future<void> toggleBiometric(bool on) async {
      if (on) {
        final bio = ref.read(biometricServiceProvider);
        if (!await bio.isAvailable) {
          if (context.mounted) {
            _toast(context, 'Este dispositivo no tiene biometría registrada');
          }
          return;
        }
        if (!await bio.authenticate('Confirma para activar la biometría')) {
          return;
        }
      }
      await ctrl.updateSettings(s.copyWith(biometric: on));
    }

    String graceLabel(int sec) => switch (sec) {
      0 => 'Inmediato',
      30 => '30 segundos',
      60 => '1 minuto',
      300 => '5 minutos',
      _ => '$sec s',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _Header('Seguridad'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(lock.pinSet ? 'Cambiar PIN' : 'Crear PIN'),
            subtitle: Text(
              lock.pinSet
                  ? 'La app se bloquea con tu PIN'
                  : 'Protege el acceso a tus cobros',
            ),
            onTap: setOrChange,
          ),
          if (lock.pinSet) ...[
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: const Text('Quitar PIN'),
              onTap: remove,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Desbloquear con biometría'),
              value: s.biometric,
              onChanged: toggleBiometric,
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Bloquear al salir de la app'),
              trailing: DropdownButton<int>(
                value: LockSettings.graceOptions.contains(s.graceSeconds)
                    ? s.graceSeconds
                    : 30,
                underline: const SizedBox.shrink(),
                items: [
                  for (final g in LockSettings.graceOptions)
                    DropdownMenuItem(value: g, child: Text(graceLabel(g))),
                ],
                onChanged: (v) => v == null
                    ? null
                    : ctrl.updateSettings(s.copyWith(graceSeconds: v)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Bloquear ahora'),
              onTap: ctrl.lockNow,
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.screenshot_monitor_outlined),
            title: const Text('Ocultar contenido en capturas'),
            subtitle: const Text(
              'Bloquea capturas de pantalla y la vista en apps recientes',
            ),
            value: s.secureScreen,
            onChanged: (v) => ctrl.updateSettings(s.copyWith(secureScreen: v)),
          ),
          const Divider(),
          const _Header('Datos'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Respaldo y restauración'),
            subtitle: const Text('Archivo cifrado con frase de recuperación'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/respaldo'),
          ),
          const Divider(),
          const _Header('General'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Buscar actualizaciones'),
            subtitle: const Text('Consulta Google Play'),
            onTap: () =>
                AppUpdateService.instance.checkAndDownload(manual: true),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline_rounded),
            title: const Text('Créditos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/credits'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
