import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../receivables/presentation/widgets/status_chip.dart';
import '../../data/attachments_repository.dart';
import '../../domain/payment_errors.dart';
import '../../domain/payment_options.dart';
import '../providers/payments_providers.dart';

const _actionLabels = {
  'register': 'Registrado',
  'confirm': 'Confirmado',
  'reject': 'Rechazado',
  'void': 'Anulado',
};

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});
  final String paymentId;

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on PaymentException catch (e) {
      if (context.mounted) _toast(context, e.message);
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'No se pudo completar la operación: $e');
      }
    }
  }

  Future<String?> _askReason(
    BuildContext context, {
    required String title,
    required String hint,
    required bool required,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: hint),
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: required && ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _addImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final f = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (f == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      () => ref
          .read(attachmentsRepositoryProvider)
          .add(
            paymentId: paymentId,
            source: File(f.path),
            mimeType:
                AttachmentsRepository.mimeFromPath(f.path) ?? 'image/jpeg',
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(paymentProvider(paymentId));
    return payment.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (p) {
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Abono no encontrado')),
          );
        }
        final fmt = DateFormat.yMMMd('es');
        final pending = p.status == 'pending_verification';
        final confirmed = p.status == 'confirmed';
        return Scaffold(
          appBar: AppBar(title: const Text('Detalle de abono')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Money.minor(
                              p.amountMinor,
                              currency: p.currency,
                            ).format(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          PaymentStatusChip(p.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${paymentMethodLabel(p.method)} · ${fmt.format(p.occurredAt)}',
                      ),
                      if (p.reference != null)
                        Text('Referencia: ${p.reference}'),
                      if (p.notes != null) Text('Notas: ${p.notes}'),
                      if (p.verifiedAt != null)
                        Text('Confirmado el ${fmt.format(p.verifiedAt!)}'),
                      if (p.voidedAt != null)
                        Text('Anulado el ${fmt.format(p.voidedAt!)}'),
                      if (p.voidReason != null)
                        Text(
                          'Motivo: ${p.voidReason}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ),
              if (pending) ...[
                const SizedBox(height: 8),
                const Text(
                  'Revisa el comprobante y confirma solo cuando el dinero esté recibido. Mientras tanto no descuenta del saldo.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar'),
                        onPressed: () => _run(
                          context,
                          () => ref
                              .read(paymentsRepositoryProvider)
                              .confirm(paymentId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Rechazar'),
                        onPressed: () async {
                          final reason = await _askReason(
                            context,
                            title: 'Rechazar abono',
                            hint: 'Motivo (opcional)',
                            required: false,
                          );
                          if (reason == null || !context.mounted) return;
                          await _run(
                            context,
                            () => ref
                                .read(paymentsRepositoryProvider)
                                .reject(paymentId, reason: reason),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (confirmed) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Anular abono'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    final reason = await _askReason(
                      context,
                      title: 'Anular abono',
                      hint: 'Motivo (obligatorio)',
                      required: true,
                    );
                    if (reason == null || !context.mounted) return;
                    await _run(
                      context,
                      () => ref
                          .read(paymentsRepositoryProvider)
                          .voidPayment(paymentId, reason: reason),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comprobantes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (p.status != 'voided' && p.status != 'rejected') ...[
                    IconButton(
                      tooltip: 'Galería',
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: () =>
                          _addImage(context, ref, ImageSource.gallery),
                    ),
                    IconButton(
                      tooltip: 'Cámara',
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: () =>
                          _addImage(context, ref, ImageSource.camera),
                    ),
                  ],
                ],
              ),
              _Attachments(paymentId: paymentId, canRemove: pending),
              const SizedBox(height: 16),
              const Text(
                'Historial',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              _History(paymentId: paymentId),
            ],
          ),
        );
      },
    );
  }
}

class _Attachments extends ConsumerWidget {
  const _Attachments({required this.paymentId, required this.canRemove});
  final String paymentId;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(attachmentsByPaymentProvider(paymentId))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin comprobantes.'),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in list) _Thumb(a, canRemove: canRemove)],
            );
          },
        );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb(this.a, {required this.canRemove});
  final Attachment a;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(attachmentsRepositoryProvider);
    return FutureBuilder<File>(
      future: repo.fileOf(a),
      builder: (context, snap) {
        final file = snap.data;
        return Stack(
          children: [
            InkWell(
              onTap: file == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.file(
                            file,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No se pudo abrir la imagen'),
                            ),
                          ),
                        ),
                      ),
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: file == null
                    ? const SizedBox(
                        width: 96,
                        height: 96,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Image.file(
                        file,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 96,
                          height: 96,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            if (canRemove)
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: () async {
                    try {
                      await repo.remove(a.id);
                    } on PaymentException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.paymentId});
  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(paymentAuditProvider(paymentId))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (logs) {
            final fmt = DateFormat.yMMMd('es').add_Hm();
            return Column(
              children: [
                for (final l in logs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(_actionLabels[l.action] ?? l.action),
                    trailing: Text(
                      fmt.format(l.occurredAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );
  }
}
