import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../collections/presentation/providers/collections_providers.dart';
import '../../../receivables/domain/balance_calculator.dart';
import '../../../receivables/domain/status_labels.dart';
import '../../../spaces/presentation/providers/spaces_providers.dart';
import '../providers/reports_providers.dart';

/// Reportes: filtros por espacio, cobro, persona, estado y rango de
/// vencimiento; desde cada fila se abre el estado de cuenta en PDF.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final notifier = ref.read(reportFilterProvider.notifier);
    final spaces = ref.watch(activeSpacesProvider).asData?.value ?? const [];
    final collections = filter.spaceId == null
        ? ref.watch(collectionsProvider).asData?.value ?? const []
        : ref
                  .watch(collectionsBySpaceProvider(filter.spaceId!))
                  .asData
                  ?.value ??
              const [];
    final rows = ref.watch(reportRowsProvider);
    final df = DateFormat('dd/MM/yy');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: filter.spaceId,
                        decoration: const InputDecoration(labelText: 'Espacio'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          for (final s in spaces)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) => notifier.set(
                          filter.copyWith(spaceId: v, collectionId: null),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(filter.spaceId),
                        isExpanded: true,
                        initialValue: filter.collectionId,
                        decoration: const InputDecoration(labelText: 'Cobro'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          for (final c in collections)
                            DropdownMenuItem(value: c.id, child: Text(c.title)),
                        ],
                        onChanged: (v) =>
                            notifier.set(filter.copyWith(collectionId: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Persona',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      notifier.set(filter.copyWith(personQuery: v)),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final s in ReceivableStatus.values)
                        FilterChip(
                          label: Text(receivableStatusLabel(s)),
                          selected: filter.status == s.name,
                          onSelected: (v) => notifier.set(
                            filter.copyWith(status: v ? s.name : null),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          filter.dueFrom == null
                              ? 'Vencimiento'
                              : '${df.format(filter.dueFrom!)} - ${df.format(filter.dueTo!)}',
                        ),
                        onPressed: () async {
                          final r = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (r != null) {
                            notifier.set(
                              filter.copyWith(dueFrom: r.start, dueTo: r.end),
                            );
                          }
                        },
                      ),
                      if (filter.dueFrom != null)
                        IconButton(
                          tooltip: 'Quitar rango',
                          icon: const Icon(Icons.close),
                          onPressed: () => notifier.set(
                            filter.copyWith(dueFrom: null, dueTo: null),
                          ),
                        ),
                    ],
                  ),
                ),
                if (filter.collectionId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push(
                        '/reportes/cobro/${filter.collectionId}',
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Reporte PDF del cobro'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: rows.when(
              loading: () => const AppLoader(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Sin resultados con estos filtros'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return ListTile(
                          title: Text(r.person),
                          subtitle: Text(
                            '${r.collectionTitle} · ${receivableStatusLabel(ReceivableStatus.values.byName(r.status))}'
                            '${r.dueAt == null ? '' : ' · vence ${df.format(r.dueAt!)}'}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Money.minor(r.balanceMinor).format(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'de ${Money.minor(r.principalMinor).format()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                          leading: Icon(
                            Icons.picture_as_pdf_outlined,
                            color: scheme.primary,
                          ),
                          onTap: () => context.push(
                            '/obligaciones/${r.receivableId}/estado-de-cuenta',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
