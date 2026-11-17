import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
import '../../../core/money/money.dart';
import '../../receivables/domain/balance_calculator.dart';
import '../../installments/data/allocation_service.dart';
import '../domain/payment_errors.dart';
import '../domain/payment_options.dart';

/// Abonos con verificación. Reglas (CUOTIVA_SPEC §4.2):
/// - solo `confirmed` descuenta saldo;
/// - no se admite exceso sobre el saldo;
/// - un pago confirmado solo se revierte con anulación motivada (sin borrar);
/// - cada cambio se audita en la misma transacción.
class PaymentsRepository {
  PaymentsRepository(this._db, this._audit, this._uuid, this._clock)
    : _allocations = AllocationService(_db, _uuid, _clock);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AllocationService _allocations;

  Stream<List<Payment>> watchByReceivable(String receivableId) =>
      (_db.select(_db.payments)
            ..where((p) => p.receivableId.equals(receivableId))
            ..orderBy([
              (p) => OrderingTerm.desc(p.occurredAt),
              (p) => OrderingTerm.desc(p.createdAt),
            ]))
          .watch();

  Stream<List<Payment>> watchRecent({int limit = 10}) =>
      (_db.select(_db.payments)
            ..orderBy([
              (p) => OrderingTerm.desc(p.occurredAt),
              (p) => OrderingTerm.desc(p.createdAt),
            ])
            ..limit(limit))
          .watch();

  Stream<Payment?> watchOne(String id) => (_db.select(
    _db.payments,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<Payment?> find(String id) => (_db.select(
    _db.payments,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Suma de pagos confirmados (alimenta `CollectedLookup` de obligaciones).
  Future<int> confirmedTotal(String receivableId) async {
    final sum = _db.payments.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.payments)
              ..addColumns([sum])
              ..where(
                _db.payments.receivableId.equals(receivableId) &
                    _db.payments.status.equals('confirmed'),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<Balance> balanceOf(String receivableId) async {
    final r = await (_db.select(
      _db.receivables,
    )..where((x) => x.id.equals(receivableId))).getSingleOrNull();
    if (r == null) throw PaymentException('Obligación no encontrada');
    final pays = await (_db.select(
      _db.payments,
    )..where((p) => p.receivableId.equals(receivableId))).get();
    return BalanceCalculator.receivable(
      principalMinor: r.principalMinor,
      payments: [
        for (final p in pays)
          PaymentLine(amountMinor: p.amountMinor, status: p.status),
      ],
      dueAt: r.dueAt,
      cancelled: r.cancelledAt != null,
      now: _clock(),
    );
  }

  /// Registra un abono. Con [confirmNow] queda confirmado; si no, pendiente
  /// de verificación (no descuenta saldo hasta confirmarlo).
  Future<Payment> register({
    required String receivableId,
    required Money amount,
    DateTime? occurredAt,
    String method = 'cash',
    String? reference,
    String? notes,
    bool confirmNow = true,
  }) async {
    if (!amount.isPositive) {
      throw PaymentException('El importe debe ser mayor a cero');
    }
    if (!paymentMethodLabels.containsKey(method)) {
      throw PaymentException('Medio de pago inválido: $method');
    }
    final now = _clock();
    final id = _uuid.v4();
    return _db.transaction(() async {
      final r = await (_db.select(
        _db.receivables,
      )..where((x) => x.id.equals(receivableId))).getSingleOrNull();
      if (r == null) throw PaymentException('Obligación no encontrada');
      if (r.cancelledAt != null) {
        throw PaymentException('La obligación está cancelada');
      }
      if (r.currency != amount.currency) {
        throw PaymentException(
          'La moneda del pago no coincide con la obligación',
        );
      }
      await _ensureWithinBalance(receivableId, amount.minor, r.currency);

      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              receivableId: receivableId,
              amountMinor: amount.minor,
              currency: Value(amount.currency),
              occurredAt: occurredAt ?? now,
              method: Value(method),
              status: Value(confirmNow ? 'confirmed' : 'pending_verification'),
              reference: Value(_clean(reference)),
              notes: Value(_clean(notes)),
              verifiedAt: Value(confirmNow ? now : null),
            ),
          );
      await _audit.log(
        entityType: 'payment',
        entityId: id,
        action: 'register',
        newValues: {
          'receivableId': receivableId,
          'amountMinor': amount.minor,
          'method': method,
          'status': confirmNow ? 'confirmed' : 'pending_verification',
        },
      );
      if (confirmNow) await _allocations.reallocate(receivableId);
      return (await find(id))!;
    });
  }

  /// pending_verification → confirmed. Revalida el saldo (otro pago pudo
  /// confirmarse antes).
  Future<void> confirm(String paymentId) => _db.transaction(() async {
    final p = await _require(paymentId);
    if (p.status != 'pending_verification') {
      throw PaymentException(
        'Solo se confirma un pago por verificar (estado: ${paymentStatusLabel(p.status)})',
      );
    }
    await _ensureWithinBalance(p.receivableId, p.amountMinor, p.currency);
    final now = _clock();
    await (_db.update(
      _db.payments,
    )..where((x) => x.id.equals(paymentId))).write(
      PaymentsCompanion(
        status: const Value('confirmed'),
        verifiedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _audit.log(
      entityType: 'payment',
      entityId: paymentId,
      action: 'confirm',
      oldValues: {'status': p.status},
      newValues: {'status': 'confirmed', 'amountMinor': p.amountMinor},
    );
    await _allocations.reallocate(p.receivableId);
  });

  /// pending_verification → rejected.
  Future<void> reject(
    String paymentId, {
    String? reason,
  }) => _db.transaction(() async {
    final p = await _require(paymentId);
    if (p.status != 'pending_verification') {
      throw PaymentException(
        'Solo se rechaza un pago por verificar (estado: ${paymentStatusLabel(p.status)})',
      );
    }
    final now = _clock();
    await (_db.update(
      _db.payments,
    )..where((x) => x.id.equals(paymentId))).write(
      PaymentsCompanion(
        status: const Value('rejected'),
        voidReason: Value(_clean(reason)),
        updatedAt: Value(now),
      ),
    );
    await _audit.log(
      entityType: 'payment',
      entityId: paymentId,
      action: 'reject',
      oldValues: {'status': p.status},
      newValues: {'status': 'rejected', 'reason': _clean(reason)},
    );
  });

  /// confirmed → voided con motivo obligatorio. El saldo se restaura porque
  /// el pago deja de contar; el registro y su auditoría permanecen.
  Future<void> voidPayment(
    String paymentId, {
    required String reason,
  }) => _db.transaction(() async {
    final why = reason.trim();
    if (why.isEmpty) throw PaymentException('Indica el motivo de la anulación');
    final p = await _require(paymentId);
    if (p.status != 'confirmed') {
      throw PaymentException(
        'Solo se anula un pago confirmado (estado: ${paymentStatusLabel(p.status)})',
      );
    }
    final now = _clock();
    await (_db.update(
      _db.payments,
    )..where((x) => x.id.equals(paymentId))).write(
      PaymentsCompanion(
        status: const Value('voided'),
        voidedAt: Value(now),
        voidReason: Value(why),
        updatedAt: Value(now),
      ),
    );
    await _audit.log(
      entityType: 'payment',
      entityId: paymentId,
      action: 'void',
      oldValues: {'status': p.status, 'amountMinor': p.amountMinor},
      newValues: {'status': 'voided', 'reason': why},
    );
    await _allocations.reallocate(p.receivableId);
  });

  Future<Payment> _require(String id) async {
    final p = await find(id);
    if (p == null) throw PaymentException('Pago no encontrado');
    return p;
  }

  Future<void> _ensureWithinBalance(
    String receivableId,
    int amountMinor,
    String currency,
  ) async {
    final b = await balanceOf(receivableId);
    if (amountMinor > b.balanceMinor) {
      throw PaymentException(
        'El pago (${Money.minor(amountMinor, currency: currency).format()}) excede el saldo pendiente '
        '(${Money.minor(b.balanceMinor, currency: currency).format()})',
      );
    }
  }

  String? _clean(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
