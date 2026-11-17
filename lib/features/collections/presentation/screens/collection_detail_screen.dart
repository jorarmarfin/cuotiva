import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../receivables/domain/receivable_errors.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../receivables/domain/balance_calculator.dart';
import '../../../receivables/presentation/providers/receivables_providers.dart';
import '../../../receivables/presentation/widgets/status_chip.dart';
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
              final balances =
                  ref
                      .watch(collectionBalancesProvider(collectionId))
                      .asData
                      ?.value ??
                  const {};
              final totals = BalanceCalculator.totals(balances.values.toList());
              String m(int v) => Money.minor(v).format();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${collectionKindLabel(c.kind)} · ${totals.participants} participante(s)'
                            '${c.fundsOwnership == 'third_party' ? ' · Fondos de terceros' : ''}',
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: totals.progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(totals.progress * 100).toStringAsFixed(1)}% recaudado',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _Stat('Comprometido', m(totals.committedMinor)),
                              _Stat('Recaudado', m(totals.collectedMinor)),
                              _Stat('Pendiente', m(totals.pendingMinor)),
                            ],
                          ),
                          if (totals.overdueMinor > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Vencido: ${m(totals.overdueMinor)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
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
                  for (final r in list) _ReceivableTile(r, balances[r.id]),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

class _ReceivableTile extends ConsumerWidget {
  const _ReceivableTile(this.r, this.balance);
  final Receivable r;
  final Balance? balance;

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
      onTap: () => context.push('/obligaciones/${r.id}'),
      subtitle: balance == null
          ? null
          : Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReceivableStatusChip(balance!.status),
                if (!cancelled)
                  Text(
                    'Saldo ${Money.minor(balance!.balanceMinor, currency: r.currency).format()}',
                  ),
              ],
            ),
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
