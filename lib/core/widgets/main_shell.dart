import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra inferior notched con FAB central incrustado.
/// Tabs: Inicio | Cobros || Personas | Reportes.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: FAB contextual (espacio, cobro, persona o abono)
        },
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
            _item(context, 1, Icons.assignment_outlined, Icons.assignment, 'Cobros'),
            const SizedBox(width: 48),
            _item(context, 2, Icons.people_outline, Icons.people, 'Personas'),
            _item(context, 3, Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, IconData active, String label) {
    final selected = shell.currentIndex == i;
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.black54;
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
