import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra inferior notched con FAB central incrustado.
/// Tabs: Inicio | Cobros || Personas | Reportes.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  /// FAB contextual: en Personas agrega persona; en el resto abre un menú.
  void _onFab(BuildContext context) {
    if (shell.currentIndex == 1) {
      context.push('/cobros/nuevo');
      return;
    }
    if (shell.currentIndex == 2) {
      context.push('/personas/nuevo');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Nuevo espacio'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/espacios/nuevo');
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_add),
              title: const Text('Nuevo cobro'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/cobros/nuevo');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Nueva persona'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/personas/nuevo');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFab(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(context, 0, Icons.home_outlined, Icons.home, 'Inicio'),
            _item(
              context,
              1,
              Icons.assignment_outlined,
              Icons.assignment,
              'Cobros',
            ),
            const SizedBox(width: 48),
            _item(context, 2, Icons.people_outline, Icons.people, 'Personas'),
            _item(
              context,
              3,
              Icons.bar_chart_outlined,
              Icons.bar_chart,
              'Reportes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int i,
    IconData icon,
    IconData active,
    String label,
  ) {
    final selected = shell.currentIndex == i;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.black54;
    return InkWell(
      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? active : icon, color: color),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
