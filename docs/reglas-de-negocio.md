# Reglas de negocio implementadas (Fase 2)

| Regla | Dónde | Test |
|---|---|---|
| Dinero en céntimos, sin `double` | `core/money/money.dart` | `money_test.dart` |
| `saldo = importe − pagos confirmados` (≥ 0) | `BalanceCalculator.receivable` | `balance_calculator_test.dart` |
| Pago pendiente/rechazado/anulado no descuenta | `BalanceCalculator` | idem |
| Pagada solo con saldo confirmado 0 | `BalanceCalculator` | idem |
| Vencida: fecha límite < hoy (por fecha) y saldo > 0 | `BalanceCalculator` | idem (fechas límite, cambio de año) |
| Pago > saldo rechazado con mensaje | `PaymentsRepository.register/confirm` | `payments_repository_test.dart` |
| Confirmar revalida saldo | `PaymentsRepository.confirm` | idem |
| Anular exige motivo, solo confirmados, restaura saldo | `PaymentsRepository.voidPayment` | idem |
| Todo movimiento auditado en la misma transacción | repositorios + `AuditService` | `spec_flows_test.dart` |
| Importe no baja de lo cobrado; no se cancela con pagos | `ReceivablesRepository` | `payments_repository_test.dart` |
| Plan de cuotas: suma exacta, fechas fin de mes | `InstallmentPlanner` | `installment_planner_test.dart` |
| Pagos asignados a la cuota más antigua primero | `AllocationService` | `installments_repository_test.dart` |
| Comprobantes: copia privada + SHA-256; quitar solo si pendiente | `AttachmentsRepository` | `attachments_repository_test.dart` |
| Totales de cobro excluyen canceladas y archivados | `BalanceCalculator.totals`, `BalancesRepository` | `balances_repository_test.dart` |

Flujos de aceptación §12 (1-5, 8, 10): `test/integration/spec_flows_test.dart`.
Pendientes por fase: PDF y compartir (§12.6-7) y rendiciones (§12.9) → Fase 3; backup y migración (§12.11-12) → Fase 4.
