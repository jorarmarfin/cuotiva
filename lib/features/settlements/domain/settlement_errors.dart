class SettlementException implements Exception {
  SettlementException(this.message);
  final String message;
  @override
  String toString() => message;
}
