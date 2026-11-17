const collectionKindLabels = {
  'credit_sale': 'Venta a crédito',
  'loan': 'Préstamo',
  'fundraising': 'Recaudación',
  'service': 'Servicio',
  'other': 'Otro',
};

String collectionKindLabel(String key) => collectionKindLabels[key] ?? key;
