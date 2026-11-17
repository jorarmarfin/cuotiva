import 'dart:async';

import '../../features/settings/data/reminders_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../money/money.dart';
import 'notification_service.dart';
import 'reminder_planner.dart';

/// Mantiene las notificaciones sincronizadas con los datos: se llama al
/// iniciar y cada vez que cambian pagos, cuotas u obligaciones.
class ReminderScheduler {
  ReminderScheduler(this._settings, this._reminders, this._sink, this._clock);

  final SettingsRepository _settings;
  final RemindersRepository _reminders;
  final ReminderSink _sink;
  final DateTime Function() _clock;

  StreamSubscription<void>? _sub;
  Timer? _debounce;

  /// Reprograma todo según ajustes y datos actuales. Devuelve cuántos programó.
  Future<int> reschedule() async {
    final s = await _settings.reminderSettings();
    final plan = ReminderPlanner.plan(
      s.enabled ? await _reminders.dueItems() : const [],
      s,
      _clock(),
      (m) => Money.minor(m).format(),
    );
    await _sink.replaceAll(plan, hideContent: s.hideContent);
    return plan.length;
  }

  /// Reprograma al cambiar los datos (con espera para agrupar cambios).
  void start() {
    unawaited(reschedule());
    _sub = _reminders.watchChanges().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(seconds: 1),
        () => unawaited(reschedule()),
      );
    });
  }

  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
  }
}
