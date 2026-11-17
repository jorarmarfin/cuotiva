import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../domain/collection_labels.dart';
import '../providers/collections_providers.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionsProvider);
    final query = ref.watch(collectionQueryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cobros')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar cobro',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref.read(collectionQueryProvider.notifier).set,
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const AppLoader(),
              error: (e, _) => Center(
                child: Text(
                  'No se pudieron cargar los cobros\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        query.isEmpty
                            ? 'Aún no tienes cobros.\nCrea uno: trajes, pasajes, préstamos, ventas…'
                            : 'Sin resultados para "$query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final fmt = DateFormat.yMMMd('es');
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_outlined),
                      ),
                      title: Text(c.title),
                      subtitle: Text(
                        [
                          collectionKindLabel(c.kind),
                          if (c.fundsOwnership == 'third_party')
                            'Fondos de terceros',
                          if (c.dueAt != null) 'vence ${fmt.format(c.dueAt!)}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/cobros/${c.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
