import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_loader.dart';
import '../providers/contacts_providers.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final query = ref.watch(contactQueryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Personas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref.read(contactQueryProvider.notifier).set,
            ),
          ),
          Expanded(
            child: contacts.when(
              loading: () => const AppLoader(),
              error: (e, _) => Center(
                child: Text(
                  'No se pudieron cargar las personas\n$e',
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
                            ? 'Aún no tienes personas.\nAgrega clientes, padres o familiares.'
                            : 'Sin resultados para "$query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          c.displayName.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(c.displayName),
                      subtitle: c.phone == null ? null : Text(c.phone!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/personas/${c.id}'),
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
