import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../providers/settlements_providers.dart';

/// Bloque recaudado / entregado / por entregar de un cobro de terceros.
class SettlementSummaryCard extends ConsumerWidget {
  const SettlementSummaryCard({super.key, required this.collectionId});
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settlementSummaryProvider(collectionId)).asData?.value;
    if (s == null) return const SizedBox.shrink();
    String m(int v) => Money.minor(v).format();
    Widget stat(String l, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: const TextStyle(fontSize: 11)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
    return Card(
      child: InkWell(
        onTap: () => context.push('/cobros/$collectionId/rendiciones'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fondos de terceros',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  stat('Recaudado', m(s.collectedMinor)),
                  stat('Entregado', m(s.deliveredMinor)),
                  stat('Por entregar', m(s.toDeliverMinor)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver rendiciones ›',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
