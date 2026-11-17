# ADR 0002 — UUID, borrado lógico y dinero

**Estado:** aceptado (2026-11-17)

- **UUID v4 como PK (texto):** permite generar ids sin coordinación y habilita sincronización futura (§15 del spec).
- **Borrado lógico (`archived_at`/`cancelled_at`):** los datos con movimientos financieros no se eliminan; se archivan o cancelan y quedan en auditoría.
- **Dinero:** `Money(minor, currency)` en enteros; `parse`/`format`/`split` centralizados; sin `double`.
- **Integridad en dos capas:** validación en dominio (mensajes claros) y CHECK/UNIQUE/FK en SQLite como red de seguridad.
- **Reglas dependientes de pagos** (no reducir bajo lo cobrado, cancelar con pagos) se inyectan mediante `CollectedLookup`; en la Fase 2 se conecta a los pagos confirmados.
