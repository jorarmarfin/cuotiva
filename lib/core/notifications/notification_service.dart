import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// Destino de los recordatorios (se sustituye en tests).
abstract interface class ReminderSink {
  /// Pide el permiso de notificaciones (Android 13+). true si está concedido.
  Future<bool> requestPermission();

  /// Cancela todo lo programado y programa [reminders].
  Future<void> replaceAll(
    List<ReminderSpec> reminders, {
    required bool hideContent,
  });
}

class LocalNotificationSink implements ReminderSink {
  LocalNotificationSink([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
      );
    } on Object {
      // Si no se reconoce la zona se usa UTC: las horas se corren, pero no falla.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> replaceAll(
    List<ReminderSpec> reminders, {
    required bool hideContent,
  }) async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'cuotas',
        'Recordatorios de cuotas',
        channelDescription: 'Avisos de cuotas por vencer y vencidas',
        importance: Importance.high,
        priority: Priority.high,
        // «private»: con la pantalla bloqueada Android oculta el contenido.
        visibility: hideContent
            ? NotificationVisibility.private
            : NotificationVisibility.public,
      ),
    );
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        r.id,
        r.title,
        r.body,
        tz.TZDateTime.from(r.when, tz.local),
        details,
        // Inexacto: no requiere el permiso de alarmas exactas.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
