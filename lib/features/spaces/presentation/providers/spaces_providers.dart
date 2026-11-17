import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';

final activeSpacesProvider = StreamProvider<List<Space>>(
  (ref) => ref.watch(spacesRepositoryProvider).watchActive(),
);

final spaceByIdProvider = FutureProvider.family<Space?, String>(
  (ref, id) => ref.watch(spacesRepositoryProvider).find(id),
);
