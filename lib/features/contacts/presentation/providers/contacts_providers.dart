import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';

class ContactQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  // ignore: use_setters_to_change_properties
  void set(String q) => state = q;
}

final contactQueryProvider = NotifierProvider<ContactQueryNotifier, String>(
  ContactQueryNotifier.new,
);

final contactsProvider = StreamProvider<List<Contact>>((ref) {
  final q = ref.watch(contactQueryProvider);
  return ref.watch(contactsRepositoryProvider).watchActive(query: q);
});

final contactByIdProvider = FutureProvider.family<Contact?, String>(
  (ref, id) => ref.watch(contactsRepositoryProvider).find(id),
);
