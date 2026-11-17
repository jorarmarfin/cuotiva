import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../collections/presentation/providers/collections_providers.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../payments/domain/payment_options.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../domain/balance_calculator.dart';
import '../providers/receivables_providers.dart';
import '../widgets/status_chip.dart';

/// Detalle de una obligación: saldo, plan de cuotas y abonos.
class ReceivableDetailScreen extends ConsumerWidget {
  const ReceivableDetailScreen({super.key, required this.receivableId});
  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivable = ref.watch(receivableProvider(receivableId));
    final balance = ref.watch(balanceProvider(receivableId));
    return receivable.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (r) {
        if (r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Obligación no encontrada')),
          );
        }
        final name = ref
            .watch(contactByIdProvider(r.contactId))
            .maybeWhen(data: (c) => c?.displayName, orElse: () => null);
        final collection = ref
            .watch(collectionByIdProvider(r.collectionId))
            .maybeWhen(data: (c) => c?.title, orElse: () => null);
        final b = balance.asData?.value;
        final canPay =
            b != null &&
            b.status != ReceivableStatus.paid &&
            b.status != ReceivableStatus.cancelled;
        return Scaffold(
          appBar: AppBar(title: Text(name ?? 'Obligación')),
          floatingActionButton: canPay
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/obligaciones/$receivableId/abono'),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar abono'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (collection != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(collection),
                ),
              if (b == null)
                const LinearProgressIndicator()
              else
                _BalanceCard(b, r.currency),
              const SizedBox(height: 16),
              _PlanSection(
                receivableId: receivableId,
                cancelled: r.cancelledAt != null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Abonos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ref
                  .watch(paymentsByReceivableProvider(receivableId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aún no hay abonos registrados.'),
                        );
                      }
                      final fmt = DateFormat.yMMMd('es');
                      return Column(
                        children: [
                          for (final p in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.payments_outlined),
                              ),
                              title: Text(
                                Money.minor(
                                  p.amountMinor,
                                  currency: p.currency,
                                ).format(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration:
                                      p.status == 'voided' ||
                                          p.status == 'rejected'
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                '${paymentMethodLabel(p.method)} · ${fmt.format(p.occurredAt)}',
                              ),
                              trailing: PaymentStatusChip(p.status),
                              onTap: () => context.push('/abonos/${p.id}'),
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.b, this.currency);
  final Balance b;
  final String currency;

  @override
  Widget build(BuildContext context) {
    String m(int v) => Money.minor(v, currency: currency).format();
    final progress = b.principalMinor == 0
        ? 0.0
        : (b.confirmedMinor / b.principalMinor).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo por cobrar'),
                ReceivableStatusChip(b.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m(b.balanceMinor),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Importe: ${m(b.principalMinor)}'),
                Text('Pagado: ${m(b.confirmedMinor)}'),
              ],
            ),
            if (b.pendingVerificationMinor > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${m(b.pendingVerificationMinor)} por verificar (aún no descuenta del saldo)',
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection({required this.receivableId, required this.cancelled});
  final String receivableId;
  final bool cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(installmentPlanProvider(receivableId));
    return plan.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        final fmt = DateFormat.yMMMd('es');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Plan de cuotas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (!cancelled)
                  TextButton(
                    onPressed: () =>
                        context.push('/obligaciones/$receivableId/plan'),
                    child: Text(list.isEmpty ? 'Definir' : 'Editar'),
                  ),
              ],
            ),
            if (list.isEmpty)
              const Text('Pago libre: sin cuotas programadas.')
            else
              for (final v in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(
                      '${v.installment.sequence}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(
                    '${Money.minor(v.installment.amountMinor).format()} · ${fmt.format(v.installment.dueAt)}',
                  ),
                  subtitle: v.paidMinor > 0 && v.remainingMinor > 0
                      ? Text('Pagado ${Money.minor(v.paidMinor).format()}')
                      : null,
                  trailing: InstallmentStatusChip(v.status),
                ),
          ],
        );
      },
    );
  }
}
