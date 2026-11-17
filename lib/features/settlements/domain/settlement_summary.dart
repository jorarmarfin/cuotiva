/// Recaudado / entregado / por entregar de un cobro de terceros.
/// `porEntregar = recaudado − entregasConfirmadas` (CUOTIVA_SPEC §4.3).
class SettlementSummary {
  const SettlementSummary({
    required this.collectedMinor,
    required this.deliveredMinor,
  });

  final int collectedMinor;
  final int deliveredMinor;

  int get toDeliverMinor => collectedMinor - deliveredMinor;
}
