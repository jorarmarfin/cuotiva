const paymentMethodLabels = {
  'cash': 'Efectivo',
  'yape': 'Yape',
  'plin': 'Plin',
  'transfer': 'Transferencia',
  'card': 'Tarjeta',
  'other': 'Otro',
};

const paymentStatusLabels = {
  'pending_verification': 'Por verificar',
  'confirmed': 'Confirmado',
  'rejected': 'Rechazado',
  'voided': 'Anulado',
};

String paymentMethodLabel(String key) => paymentMethodLabels[key] ?? key;
String paymentStatusLabel(String key) => paymentStatusLabels[key] ?? key;
