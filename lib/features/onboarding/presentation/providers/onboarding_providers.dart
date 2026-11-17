import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';

const onboardingKey = 'onboarding_done';

/// true si ya se completó (o si ya hay datos de un uso anterior).
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  if (await settings.get(onboardingKey) == '1') return true;
  // Instalaciones previas al onboarding: no se les vuelve a mostrar.
  final spaces = await ref.read(spacesRepositoryProvider).watchActive().first;
  return spaces.isNotEmpty;
});

Future<void> completeOnboarding(WidgetRef ref) async {
  await ref.read(settingsRepositoryProvider).set(onboardingKey, '1');
  ref.invalidate(onboardingDoneProvider);
}
