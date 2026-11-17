class ReceivableException implements Exception {
  ReceivableException(this.message);
  final String message;
  @override
  String toString() => message;
}
