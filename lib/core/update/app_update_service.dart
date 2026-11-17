import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Messenger global para mostrar avisos desde servicios sin `BuildContext`.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Actualización flexible de Google Play (solo Android). Al publicar una
/// versión nueva, Play la detecta en el siguiente arranque; se descarga en
/// segundo plano y se pide reiniciar para instalarla.
///
/// Privacidad: solo consulta a Google Play del dispositivo; Cuotiva no envía
/// datos propios a ningún servicio.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  StreamSubscription<InstallStatus>? _subscription;

  /// No bloqueante: si Play Services no está disponible (emulador, instalación
  /// manual de APK, desarrollo local) falla en silencio y no rompe el arranque.
  /// Con [manual] = true informa el resultado al usuario.
  Future<void> checkAndDownload({bool manual = false}) async {
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        if (manual) _toast('Cuotiva está actualizada.');
        return;
      }
      if (!info.flexibleUpdateAllowed) {
        if (manual) _toast('Hay una versión nueva en Google Play.');
        return;
      }

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return;
      if (manual) _toast('Descargando actualización…');

      // startFlexibleUpdate() termina cuando la descarga *empieza*: hay que
      // escuchar el stream y recién al terminar pedir el reinicio.
      await _subscription?.cancel();
      _subscription = InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded) _promptRestart();
      });
    } catch (_) {
      if (manual) {
        _toast(
          'No se pudo buscar actualizaciones (requiere instalación desde Google Play).',
        );
      }
    }
  }

  void _toast(String msg) =>
      rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));

  void _promptRestart() {
    rootMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        duration: Duration(days: 1),
        content: Text('Hay una actualización lista para instalar.'),
        action: SnackBarAction(
          label: 'REINICIAR',
          onPressed: InAppUpdate.completeFlexibleUpdate,
        ),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
