import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../installments/data/installments_repository.dart';

final paymentsByReceivableProvider =
    StreamProvider.family<List<Payment>, String>(
      (ref, receivableId) =>
          ref.watch(paymentsRepositoryProvider).watchByReceivable(receivableId),
    );

final installmentPlanProvider =
    StreamProvider.family<List<InstallmentView>, String>(
      (ref, receivableId) =>
          ref.watch(installmentsRepositoryProvider).watchPlan(receivableId),
    );

final attachmentsByPaymentProvider =
    StreamProvider.family<List<Attachment>, String>(
      (ref, paymentId) =>
          ref.watch(attachmentsRepositoryProvider).watchByPayment(paymentId),
    );

final paymentProvider = StreamProvider.family<Payment?, String>(
  (ref, id) => ref.watch(paymentsRepositoryProvider).watchOne(id),
);

final paymentAuditProvider = StreamProvider.family<List<AuditLog>, String>(
  (ref, paymentId) =>
      ref.watch(auditServiceProvider).watchFor('payment', paymentId),
);
