import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../receivables/domain/receivable_errors.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../receivables/presentation/providers/receivables_providers.dart';
import '../../domain/collection_labels.dart';
import '../providers/collections_providers.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});
  final String collectionId;

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Archivar cobro?'),
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
      await ref.read(collectionsRepositoryProvider).archive(collectionId);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionByIdProvider(collectionId));
    final receivables = ref.watch(
      receivablesByCollectionProvider(collectionId),
    );
    return collection.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Cobro no encontrado')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(c.title),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/cobros/$collectionId/editar'),
              ),
              IconButton(
                tooltip: 'Archivar',
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _archive(context, ref),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/cobros/$collectionId/asignar'),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Asignar personas'),
          ),
          body: receivables.when(
            loading: () => const AppLoader(),
            error: (e, _) => Center(
              child: Text('No se pudieron cargar las obligaciones\n$e'),
            ),
            data: (list) {
              final total = list
                  .where((r) => r.cancelledAt == null)
                  .fold<int>(0, (s, r) => s + r.principalMinor);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(collectionKindLabel(c.kind)),
                      subtitle: Text(
                        '${list.length} participante(s)'
                        '${c.fundsOwnership == 'third_party' ? ' · Fondos de terceros' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Comprometido',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            Money.minor(total).format(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nadie tiene obligaciones en este cobro.\nUsa "Asignar personas".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final r in list) _ReceivableTile(r),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ReceivableTile extends ConsumerWidget {
  const _ReceivableTile(this.r);
  final Receivable r;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(
      text: (r.principalMinor / 100).toStringAsFixed(2),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar importe'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'S/ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;
    try {
      await ref
          .read(receivablesRepositoryProvider)
          .updatePrincipal(r.id, Money.parse(value, currency: r.currency));
    } on FormatException {
      if (context.mounted) _toast(context, 'Importe inválido');
    } on ReceivableException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar obligación?'),
        content: const Text(
          'Dejará de contar en el total comprometido. Queda registrada en la auditoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar obligación'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(receivablesRepositoryProvider).cancel(r.id);
    } on ReceivableException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref
        .watch(contactByIdProvider(r.contactId))
        .maybeWhen(
          data: (c) => c?.displayName ?? 'Persona eliminada',
          orElse: () => '…',
        );
    final cancelled = r.cancelledAt != null;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(name),
      subtitle: cancelled ? const Text('Cancelada') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Money.minor(r.principalMinor, currency: r.currency).format(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (!cancelled)
            PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? _edit(context, ref) : _cancel(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar importe')),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancelar obligación'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
