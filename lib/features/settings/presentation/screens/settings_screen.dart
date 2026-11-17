import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/update/app_update_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          // TODO: PIN/biometría, notificaciones, respaldos (Fase 4)
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
