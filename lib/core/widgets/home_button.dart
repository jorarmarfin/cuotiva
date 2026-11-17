import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Vuelve al inicio cerrando todas las pantallas abiertas encima.
/// Se oculta si ya no hay nada que cerrar.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null || !router.canPop()) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Ir al inicio',
      onPressed: () => router.go('/'),
    );
  }
}
