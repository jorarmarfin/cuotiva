import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../spaces/presentation/providers/spaces_providers.dart';
import '../../domain/collection_labels.dart';
import '../providers/collections_providers.dart';

const _statusLabels = {
  CollectionStatusFilter.all: 'Todos',
  CollectionStatusFilter.withBalance: 'Con saldo',
  CollectionStatusFilter.overdue: 'Vencidos',
  CollectionStatusFilter.paid: 'Pagados',
};

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionsProvider);
    final totals =
        ref.watch(collectionTotalsProvider).asData?.value ?? const {};
    final spaces = ref.watch(activeSpacesProvider).asData?.value ?? const [];
    final query = ref.watch(collectionQueryProvider);
    final status = ref.watch(collectionStatusFilterProvider);
    final spaceFilter = ref.watch(collectionSpaceFilterProvider);
    final spaceNames = {for (final s in spaces) s.id: s.name};

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
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in _statusLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: status == e.key,
                      onSelected: (_) => ref
                          .read(collectionStatusFilterProvider.notifier)
                          .set(e.key),
                    ),
                  ),
                if (spaces.isNotEmpty) const VerticalDivider(width: 16),
                for (final s in spaces)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s.name),
                      selected: spaceFilter == s.id,
                      onSelected: (v) => ref
                          .read(collectionSpaceFilterProvider.notifier)
                          .set(v ? s.id : null),
                    ),
                  ),
              ],
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
              data: (all) {
                final list = [
                  for (final c in all)
                    if (matchesStatusFilter(status, totals[c.id])) c,
                ];
                if (list.isEmpty) {
                  final filtered =
                      query.isNotEmpty ||
                      status != CollectionStatusFilter.all ||
                      spaceFilter != null;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        filtered ? 'Sin resultados con estos filtros.' : 'Aún no tienes cobros.\nCrea uno: trajes, pasajes, préstamos, ventas…',
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
                    final t = totals[c.id];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_outlined),
                      ),
                      title: Text(c.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (spaceNames[c.spaceId] != null)
                                spaceNames[c.spaceId]!,
                              collectionKindLabel(c.kind),
                              if (c.fundsOwnership == 'third_party')
                                'Fondos de terceros',
                              if (c.dueAt != null)
                                'vence ${fmt.format(c.dueAt!)}',
                            ].join(' · '),
                          ),
                          if (t != null && t.committedMinor > 0) ...[
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: t.progress.clamp(0.0, 1.0),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        ],
                      ),
                      trailing: t == null || t.committedMinor == 0
                          ? const Icon(Icons.chevron_right)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Money.minor(t.pendingMinor).format(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  t.overdueMinor > 0 ? 'vencido' : 'pendiente',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.overdueMinor > 0
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              ],
                            ),
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
