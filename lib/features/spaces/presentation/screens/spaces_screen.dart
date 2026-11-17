import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../domain/space_presets.dart';
import '../providers/spaces_providers.dart';

class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(activeSpacesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis espacios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/espacios/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo espacio'),
      ),
      body: spaces.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(
          child: Text(
            'No se pudieron cargar los espacios\n$e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aún no tienes espacios.\nCrea uno para Familia, Negocio, Colegio, Capilla…',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = list[i];
              final color = Color(s.color);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(spaceIconData(s.icon), color: color),
                  ),
                  title: Text(s.name),
                  subtitle: s.description == null
                      ? null
                      : Text(
                          s.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/espacios/${s.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
