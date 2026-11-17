import 'balance_calculator.dart';

String receivableStatusLabel(ReceivableStatus s) => switch (s) {
  ReceivableStatus.pending => 'Pendiente',
  ReceivableStatus.partial => 'Abonado',
  ReceivableStatus.paid => 'Pagado',
  ReceivableStatus.overdue => 'Vencido',
  ReceivableStatus.cancelled => 'Cancelado',
};
