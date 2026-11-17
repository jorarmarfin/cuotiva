import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Inicio provisional: accesos. El resumen de saldos llega en la Fase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuotiva'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/ajustes'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Mis espacios'),
              subtitle: const Text('Familia, negocio, colegio, capilla…'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/espacios'),
            ),
          ),
        ],
      ),
    );
  }
}
