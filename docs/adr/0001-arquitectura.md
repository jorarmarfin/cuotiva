# ADR 0001 — Arquitectura base

**Estado:** aceptado (2026-11-17)

## Decisiones
- **Local-first, mono-usuario**, sin backend en V1.
- **Riverpod** (estado/DI) y **GoRouter** (navegación).
- **Drift + SQLite**; el `QueryExecutor` se inyecta para tests y para cifrar con SQLCipher en la Fase 4.
- **Dinero en enteros** (unidad mínima) + ISO 4217; nunca `double`.
- **Saldo y estado de obligación derivados** de pagos confirmados; no se almacenan a mano.
- **Sin borrado silencioso** de datos financieros: anulación + auditoría (`audit_logs`).
- Features con `data/`, `domain/`, `presentation/`; la UI no ejecuta SQL.
