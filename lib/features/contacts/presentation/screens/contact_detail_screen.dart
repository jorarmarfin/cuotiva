import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../collections/presentation/providers/collections_providers.dart';
import '../../../receivables/presentation/providers/receivables_providers.dart';
import '../providers/contacts_providers.dart';
import '../../../../core/widgets/home_button.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});
  final String contactId;

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Archivar persona?'),
        content: const Text(
          'Se oculta de la lista, pero conserva su historial de cobros y pagos.',
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
      await ref.read(contactsRepositoryProvider).archive(contactId);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactByIdProvider(contactId));
    return contact.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Persona no encontrada')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(c.displayName),
            actions: [
              const HomeButton(),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/personas/$contactId/editar'),
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
              if (c.phone != null)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(c.phone!),
                ),
              if (c.email != null)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(c.email!),
                ),
              if (c.notes != null)
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: Text(c.notes!),
                ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Obligaciones',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ref
                  .watch(receivablesByContactProvider(contactId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Esta persona aún no tiene obligaciones.',
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final r in list)
                            ListTile(
                              leading: const Icon(Icons.assignment_outlined),
                              title: Text(
                                ref
                                    .watch(
                                      collectionByIdProvider(r.collectionId),
                                    )
                                    .maybeWhen(
                                      data: (c) => c?.title ?? 'Cobro',
                                      orElse: () => '…',
                                    ),
                              ),
                              subtitle: r.cancelledAt != null
                                  ? const Text('Cancelada')
                                  : null,
                              trailing: Text(
                                Money.minor(
                                  r.principalMinor,
                                  currency: r.currency,
                                ).format(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () =>
                                  context.push('/cobros/${r.collectionId}'),
                            ),
                        ],
                      );
                    },
                  ),
            ],
          ),
        );
      },
    );
  }
}
