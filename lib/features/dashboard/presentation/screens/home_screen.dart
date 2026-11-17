import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../payments/domain/payment_options.dart';
import '../../../receivables/presentation/widgets/status_chip.dart';
import '../../../spaces/presentation/providers/spaces_providers.dart';
import '../providers/dashboard_providers.dart';

/// Inicio: resumen general de cobros (CUOTIVA_SPEC §5.2).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(dashboardTotalsProvider);
    final selected = ref.watch(selectedSpaceProvider);
    final spaces = ref.watch(activeSpacesProvider).asData?.value ?? const [];
    String m(int v) => Money.minor(v).format();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuotiva'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/ajustes'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '¡Hola!',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Text('Resumen general'),
          if (spaces.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: selected == null,
                      onSelected: (_) =>
                          ref.read(selectedSpaceProvider.notifier).select(null),
                    ),
                  ),
                  for (final s in spaces)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.name),
                        selected: selected == s.id,
                        onSelected: (_) => ref
                            .read(selectedSpaceProvider.notifier)
                            .select(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          totals.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('No se pudo calcular el resumen: $e'),
            data: (t) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brand, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.savings_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saldo por cobrar',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              m(t.pendingMinor),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.south_west,
                        color: AppColors.mint,
                        label: 'Recaudado',
                        value: m(t.collectedMinor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.schedule,
                        color: t.overdueMinor > 0
                            ? AppColors.error
                            : AppColors.amber,
                        label: t.overdueMinor > 0 ? 'Vencido' : 'Total',
                        value: m(
                          t.overdueMinor > 0
                              ? t.overdueMinor
                              : t.committedMinor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: t.progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(t.progress * 100).toStringAsFixed(1)}% recaudado de ${m(t.committedMinor)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Próximos vencimientos'),
          const _UpcomingList(),
          const SizedBox(height: 16),
          const _SectionTitle('Pagos recientes'),
          const _RecentPayments(),
          const SizedBox(height: 16),
          _NavTile(
            icon: Icons.layers_outlined,
            title: 'Mis espacios',
            subtitle: 'Familia, negocio, colegio, capilla…',
            onTap: () => context.push('/espacios'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(upcomingDueProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nada por vencer en los próximos 30 días.'),
              );
            }
            final fmt = DateFormat.MMMd('es');
            return Column(
              children: [
                for (final d in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      d.overdue ? Icons.warning_amber_rounded : Icons.event,
                      color: d.overdue ? AppColors.error : null,
                    ),
                    title: Text(
                      ref
                          .watch(contactByIdProvider(d.contactId))
                          .maybeWhen(
                            data: (c) => c?.displayName ?? 'Persona',
                            orElse: () => '…',
                          ),
                    ),
                    subtitle: Text(
                      d.overdue
                          ? 'Venció el ${fmt.format(d.dueAt)}'
                          : 'Vence el ${fmt.format(d.dueAt)}',
                    ),
                    trailing: Text(
                      Money.minor(
                        d.remainingMinor,
                        currency: d.currency,
                      ).format(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () =>
                        context.push('/obligaciones/${d.receivableId}'),
                  ),
              ],
            );
          },
        );
  }
}

class _RecentPayments extends ConsumerWidget {
  const _RecentPayments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recentPaymentsProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no hay abonos registrados.'),
              );
            }
            final fmt = DateFormat.MMMd('es');
            return Column(
              children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.payments_outlined),
                    ),
                    title: Text(
                      Money.minor(p.amountMinor, currency: p.currency).format(),
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
        );
  }
}
