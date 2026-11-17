import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup/backup_service.dart';
import 'app.dart';

/// Raíz de la app: aplica una restauración pendiente ANTES de abrir la base y
/// permite «reiniciar» recreando el `ProviderScope` (cierra la base actual).
class RestartHost extends StatefulWidget {
  const RestartHost({super.key});

  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_RestartHostState>()?._restart();

  @override
  State<RestartHost> createState() => _RestartHostState();
}

class _RestartHostState extends State<RestartHost> {
  var _generation = 0;
  late Future<String?> _boot = _applyPending();

  /// Devuelve un mensaje de error si la restauración pendiente falló.
  Future<String?> _applyPending() async {
    try {
      final paths = await BackupPaths.resolve();
      await RestoreApplier(paths).apply();
      return null;
    } on Object catch (e) {
      return 'No se pudo aplicar la restauración (se conservaron tus datos): $e';
    }
  }

  void _restart() => setState(() {
    _generation++;
    _boot = _applyPending();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _boot,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      return ProviderScope(
        key: ValueKey(_generation),
        child: CuotivaApp(startupMessage: snap.data),
      );
    },
  );
}
