import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/reminder_planner.dart';
import '../../../../core/providers/repository_providers.dart';

final reminderSettingsProvider = FutureProvider.autoDispose<ReminderSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).reminderSettings(),
);

/// Ajustes de recordatorios de cuotas.
class ReminderSettingsSection extends ConsumerWidget {
  const ReminderSettingsSection({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings s,
  ) async {
    await ref.read(settingsRepositoryProvider).saveReminderSettings(s);
    await ref.read(reminderSchedulerProvider).reschedule();
    ref.invalidate(reminderSettingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reminderSettingsProvider).asData?.value;
    if (s == null) return const SizedBox.shrink();

    Future<void> toggle(bool on) async {
      if (on) {
        final granted = await ref
            .read(reminderSinkProvider)
            .requestPermission();
        if (!granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permiso de notificaciones denegado. Actívalo en los ajustes del sistema.',
                ),
              ),
            );
          }
          return;
        }
      }
      if (context.mounted) await _save(context, ref, s.copyWith(enabled: on));
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Recordatorios de cuotas'),
          subtitle: const Text('Por vencer, vence hoy y vencidas'),
          value: s.enabled,
          onChanged: toggle,
        ),
        if (s.enabled) ...[
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Avisar antes del vencimiento'),
            trailing: DropdownButton<int>(
              value: s.daysBefore,
              underline: const SizedBox.shrink(),
              items: [
                for (final d in ReminderSettings.daysOptions)
                  DropdownMenuItem(
                    value: d,
                    child: Text(d == 0 ? 'No avisar antes' : '$d día(s)'),
                  ),
              ],
              onChanged: (v) => v == null
                  ? null
                  : _save(context, ref, s.copyWith(daysBefore: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Hora del aviso'),
            trailing: Text('${s.hour.toString().padLeft(2, '0')}:00'),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: s.hour, minute: 0),
              );
              if (t != null && context.mounted) {
                await _save(context, ref, s.copyWith(hour: t.hour));
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Ocultar contenido en pantalla bloqueada'),
            value: s.hideContent,
            onChanged: (v) => _save(context, ref, s.copyWith(hideContent: v)),
          ),
        ],
      ],
    );
  }
}
