import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/settlement_errors.dart';
import '../providers/settlements_providers.dart';
import '../widgets/settlement_summary_card.dart';

/// Entregas del dinero recaudado a su destinatario.
class SettlementsScreen extends ConsumerWidget {
  const SettlementsScreen({super.key, required this.collectionId});
  final String collectionId;

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final who = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar entrega'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Importe',
                    prefixText: 'S/ ',
                  ),
                  validator: (v) {
                    try {
                      return Money.parse(v ?? '').isPositive
                          ? null
                          : 'Importe inválido';
                    } on FormatException {
                      return 'Importe inválido';
                    }
                  },
                ),
                TextFormField(
                  controller: who,
                  decoration: const InputDecoration(
                    labelText: 'Entregado a (opcional)',
                  ),
                ),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    final amountText = amount.text;
    final whoText = who.text;
    final notesText = notes.text;
    amount.dispose();
    who.dispose();
    notes.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .register(
            collectionId: collectionId,
            amount: Money.parse(amountText),
            recipientName: whoText,
            notes: notesText,
          );
    } on SettlementException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _void(BuildContext context, WidgetRef ref, Settlement s) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular entrega?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo (obligatorio)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .voidSettlement(s.id, reason: text);
    } on SettlementException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(settlementsByCollectionProvider(collectionId));
    final df = DateFormat('d MMM y', 'es');
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rendiciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _register(context, ref),
        icon: const Icon(Icons.outbox_outlined),
        label: const Text('Registrar entrega'),
      ),
      body: list.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SettlementSummaryCard(collectionId: collectionId),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aún no hay entregas registradas.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final s in items)
              ListTile(
                leading: Icon(
                  s.status == 'voided' ? Icons.block : Icons.outbox_outlined,
                  color: s.status == 'voided' ? scheme.outline : scheme.primary,
                ),
                title: Text(
                  Money.minor(s.amountMinor, currency: s.currency).format(),
                  style: TextStyle(
                    decoration: s.status == 'voided'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  [
                    df.format(s.occurredAt),
                    if (s.recipientName != null) 'a ${s.recipientName}',
                    if (s.status == 'voided') 'Anulada: ${s.voidReason}',
                    if (s.notes != null) s.notes!,
                  ].join(' · '),
                ),
                trailing: s.status == 'confirmed'
                    ? IconButton(
                        tooltip: 'Anular',
                        icon: const Icon(Icons.undo),
                        onPressed: () => _void(context, ref, s),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
