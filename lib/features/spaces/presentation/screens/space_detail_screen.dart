import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../collections/domain/collection_labels.dart';
import '../../../collections/presentation/providers/collections_providers.dart';
import '../../domain/space_presets.dart';
import '../providers/spaces_providers.dart';
import '../../../../core/widgets/home_button.dart';

class SpaceDetailScreen extends ConsumerWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});
  final String spaceId;

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Archivar espacio?'),
        content: const Text(
          'Se oculta de la lista, pero conserva todo su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(spacesRepositoryProvider).archive(spaceId);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceByIdProvider(spaceId));
    return space.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (s) {
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Espacio no encontrado')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(s.name),
            actions: [
              const HomeButton(),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/espacios/$spaceId/editar'),
              ),
              IconButton(
                tooltip: 'Archivar',
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _archive(context, ref),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(s.color).withValues(alpha: 0.15),
                  child: Icon(spaceIconData(s.icon), color: Color(s.color)),
                ),
                title: Text(s.name),
                subtitle: s.description == null ? null : Text(s.description!),
              ),
              const Divider(),
              ref
                  .watch(collectionsBySpaceProvider(spaceId))
                  .when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => Column(
                      children: [
                        if (list.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Este espacio aún no tiene cobros.'),
                          ),
                        for (final c in list)
                          ListTile(
                            leading: const Icon(Icons.assignment_outlined),
                            title: Text(c.title),
                            subtitle: Text(collectionKindLabel(c.kind)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/cobros/${c.id}'),
                          ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/cobros/nuevo?espacio=$spaceId'),
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo cobro en este espacio'),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
