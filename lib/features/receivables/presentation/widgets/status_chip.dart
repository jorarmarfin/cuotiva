import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../installments/data/installments_repository.dart';
import '../../domain/balance_calculator.dart';
import '../../domain/status_labels.dart';

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

Color receivableStatusColor(ReceivableStatus s) => switch (s) {
  ReceivableStatus.paid => const Color(0xFF059669),
  ReceivableStatus.overdue => AppColors.error,
  ReceivableStatus.partial => AppColors.brand,
  ReceivableStatus.pending => const Color(0xFFB45309),
  ReceivableStatus.cancelled => Colors.grey,
};

class ReceivableStatusChip extends StatelessWidget {
  const ReceivableStatusChip(this.status, {super.key});
  final ReceivableStatus status;

  @override
  Widget build(BuildContext context) =>
      _Chip(receivableStatusLabel(status), receivableStatusColor(status));
}

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'confirmed' => ('Confirmado', const Color(0xFF059669)),
      'pending_verification' => ('Por verificar', const Color(0xFFB45309)),
      'rejected' => ('Rechazado', AppColors.error),
      'voided' => ('Anulado', Colors.grey),
      _ => (status, Colors.grey),
    };
    return _Chip(label, color);
  }
}

class InstallmentStatusChip extends StatelessWidget {
  const InstallmentStatusChip(this.status, {super.key});
  final InstallmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InstallmentStatus.paid => ('Pagada', const Color(0xFF059669)),
      InstallmentStatus.partial => ('Parcial', AppColors.brand),
      InstallmentStatus.overdue => ('Vencida', AppColors.error),
      InstallmentStatus.pending => ('Pendiente', const Color(0xFFB45309)),
    };
    return _Chip(label, color);
  }
}
