/// Generación y validación de planes de cuotas (puro, sin DB).
library;

class InstallmentDraft {
  const InstallmentDraft({required this.dueAt, required this.amountMinor});
  final DateTime dueAt;
  final int amountMinor;
}

class PlanException implements Exception {
  PlanException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class InstallmentPlanner {
  /// Cuotas iguales; el resto de céntimos va a las primeras (suma exacta).
  /// Las fechas avanzan [intervalMonths] meses ajustando fin de mes
  /// (31 ene → 28/29 feb → 31 mar).
  static List<InstallmentDraft> even({
    required int principalMinor,
    required int count,
    required DateTime firstDue,
    int intervalMonths = 1,
  }) {
    if (principalMinor <= 0) {
      throw PlanException('El importe debe ser mayor a cero');
    }
    if (count < 1) throw PlanException('Indica al menos una cuota');
    if (intervalMonths < 1) {
      throw PlanException('El intervalo debe ser de al menos 1 mes');
    }
    if (principalMinor < count) {
      throw PlanException('Hay más cuotas que céntimos por repartir');
    }
    final base = principalMinor ~/ count;
    final rest = principalMinor % count;
    return [
      for (var i = 0; i < count; i++)
        InstallmentDraft(
          dueAt: addMonths(firstDue, i * intervalMonths),
          amountMinor: base + (i < rest ? 1 : 0),
        ),
    ];
  }

  /// Valida un plan editado a mano: importes positivos y suma == total.
  static void validate(List<InstallmentDraft> drafts, int principalMinor) {
    if (drafts.isEmpty) {
      throw PlanException('El plan debe tener al menos una cuota');
    }
    var sum = 0;
    for (final d in drafts) {
      if (d.amountMinor <= 0) {
        throw PlanException('Cada cuota debe ser mayor a cero');
      }
      sum += d.amountMinor;
    }
    if (sum != principalMinor) {
      final diff = principalMinor - sum;
      throw PlanException(
        diff > 0
            ? 'Faltan ${_fmt(diff)} para completar el total de las cuotas'
            : 'Las cuotas exceden el total en ${_fmt(-diff)}',
      );
    }
  }

  static DateTime addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
  }

  static String _fmt(int minor) {
    final whole = (minor ~/ 100).toString();
    final frac = (minor % 100).toString().padLeft(2, '0');
    return 'S/ $whole.$frac';
  }
}
