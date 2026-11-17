# ADR 0003 — Saldo derivado y asignación de pagos a cuotas

**Estado:** aceptado (2026-11-17)

## Decisiones
- **El saldo y el estado de una obligación nunca se guardan**: `BalanceCalculator` los deriva de `principal_minor` y de los pagos `confirmed`. Así no hay switches aislados ni estados que se desincronicen (§4.2). `overdue` también es derivado (fecha límite vs. hoy, comparando solo la fecha: vence al terminar el día límite).
- **Solo `confirmed` descuenta.** `pending_verification` es informativo y se muestra aparte; un comprobante adjunto no equivale a pago confirmado.
- **Anular ≠ borrar.** Un pago confirmado pasa a `voided` con motivo obligatorio; el registro y su auditoría permanecen y el saldo se restaura al dejar de contar.
- **Sin exceso en V1.** `register` y `confirm` validan el pago contra el saldo confirmado en la misma transacción (al confirmar se revalida, porque otro pago pudo confirmarse antes).
- **Asignaciones a cuotas son datos derivados.** `AllocationService.reallocate` borra y recalcula todas las asignaciones de una obligación (pagos confirmados en orden cronológico, cuota más antigua primero) dentro de la misma transacción que cambia un pago o el plan. Por construcción la suma asignada de un pago no supera su importe ni el de la cuota.
- **Plan de cuotas cerrado:** la suma debe ser exactamente el importe de la obligación; con plan, el importe solo cambia reajustando el plan.
- **Reglas dependientes de pagos** (no reducir bajo lo cobrado, cancelar con pagos) usan `PaymentsRepository.confirmedTotal` inyectado como `CollectedLookup`.

## Consecuencias
- Cada lectura de saldo recalcula desde los pagos (consultas por lote en `BalancesRepository`); es barato para el volumen esperado (decenas de participantes) y elimina una clase entera de inconsistencias.
