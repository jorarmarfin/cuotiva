import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
