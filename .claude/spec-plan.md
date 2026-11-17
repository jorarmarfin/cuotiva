# Plan de Fases: Cuotiva

> Generado: 2026-11-17. Última actualización: 2026-11-17.
> Fuente: `spec/CUOTIVA_SPEC.md` (§13 define las 6 fases; aquí se detallan).
> Este archivo es la fuente de verdad del progreso. Actualízalo al cerrar o avanzar cada fase.

## Información General
- **Stack**: Flutter (Android) + Riverpod + GoRouter + Drift/SQLite (SQLCipher en Fase 4) + pdf/printing + share_plus + local_auth + flutter_local_notifications
- **Usuarios**: mono-usuario (administrador de cobros: comerciante, tesorero de colegio/capilla, familia); sin multiusuario
- **Restricciones**: 100% offline/local-first; sin backend ni login remoto; dinero en enteros (céntimos) + ISO 4217; textos en español; todo movimiento financiero auditado; pago pendiente de verificación no descuenta saldo
- **Timeline estimado**: ~5 semanas (2-5 días por fase)

## Estado Actual
- **Fase activa**: Fase 4 — Seguridad y cierre V1
- **Progreso**: 4 de 6 fases completadas
- **Bloqueadores**: ninguno
- **Próximo paso concreto**: Fase 4 — spike 0.5 día SQLCipher + Drift (ADR), luego PIN/KDF

## Fase 0: Base del proyecto — COMPLETADA

**Duración estimada**: 2 días
**Objetivo**: proyecto compilable con estructura, tema, router y herramientas de calidad.
**Complejidad**: Bajo

### Requisitos previos
- Logo, spec y mockups en la raíz (hecho)

### Entregables (Definición de Done)

#### Frontend / base
- [x] `flutter create` Android, `applicationId` com.luisitomayta.cuotiva
- [x] Estructura `lib/app`, `lib/core/*`, `lib/features/*/{data,domain,presentation}`
- [x] Tema Material 3 con paleta del spec (`AppColors`, `AppTheme`, Poppins)
- [x] GoRouter con shell (bottom nav notched + FAB) y rutas placeholder
- [x] Riverpod (`ProviderScope`), localización es-PE
- [x] `AppLoader` (FourRotatingDots), pantalla Ajustes + Créditos
- [x] Icono adaptativo + splash; `run.sh`; `scripts/build_release.sh`
- [x] Lints estrictos en `analysis_options.yaml` (prefer_const, require_trailing_commas, etc.)
- [x] Drift: `AppDatabase` base, `PRAGMA foreign_keys=ON`, build_runner funcionando
- [x] Providers raíz (database, clock inyectable, uuid)

#### Tests
- [x] Smoke test de arranque
- [-] CI (GitHub Actions): descartado, el usuario no lo quiere (consumía recursos de GitHub)

#### Documentación
- [x] `README.md` con comandos (§14)
- [x] `CHANGELOG.md`
- [x] `docs/adr/0001-arquitectura.md` (Riverpod, Drift, local-first, dinero en céntimos)

### Posibles obstáculos
- Conflictos de versiones (ya ocurrió win32: share_plus/secure_storage/package_info) → fijar versiones en pubspec.
- SQLCipher + Drift: decidir integración en Fase 4; no usar rutas que impidan cambiar el `QueryExecutor` luego.

### Notas de avance
- 2026-11-17: scaffold generado con skill flutter-new-app; analyze limpio, test OK.
- 2026-11-17: Fase 0 cerrada (lints, Drift base, CI, README/CHANGELOG/ADR 0001).

---

## Fase 1: Núcleo de datos — COMPLETADA

**Duración estimada**: 4 días
**Objetivo**: espacios, contactos, cobros y obligaciones con esquema Drift, repositorios, casos de uso y UI CRUD básica.
**Complejidad**: Medio

### Requisitos previos
- Fase 0 completa (Drift configurado)

### Entregables (Definición de Done)

#### Datos
- [x] Servicio `core/money`: `Money(minor, currency)`, formateo S/, parseo, redondeo centralizado (con tests PRIMERO)
- [x] Tablas: `spaces`, `contacts`, `collections`, `receivables`, `installments`, `app_settings`, `audit_logs` (id UUID, created_at, updated_at, archived_at donde aplique)
- [x] FK, índices (§8), CHECK de montos positivos / estados válidos
- [x] Esquema v1 + estrategia de migraciones (`schemaVersion`, `stepByStep`)
- [x] Repositorios (spaces, contacts, collections, receivables) expuestos por providers Riverpod
- [x] Servicio de auditoría reutilizable (escritura dentro de la misma transacción)

#### Frontend
- [x] Mis espacios: lista, crear/editar/archivar (color, ícono, descripción)
- [x] Detalle de espacio (cabecera, editar, archivar, lista de cobros)
- [x] Personas: lista, crear/editar, detalle con historial de obligaciones (contacto global compartido entre espacios)
- [x] Crear/editar cobro (tipo, `funds_ownership`, fechas, notas)
- [x] Crear obligación + asignación masiva «S/ 150 a cada participante» (pantalla Asignar personas; vencimiento por obligación pendiente)
- [x] Estados vacío / carga / error en cada lista

#### Tests
- [x] Unit: Money (exactitud en céntimos)
- [x] Unit: contacto compartido entre espacios y cobros
- [x] Unit: no reducir obligación por debajo de lo cobrado (regla ya modelada aunque aún no haya pagos)
- [x] Test de migración/esquema v1 con DB en memoria

#### Documentación
- [x] Diagrama del modelo de datos en `docs/modelo-datos.md`
- [x] ADR 0002: UUID, borrado lógico, Money

### Posibles obstáculos
- Sobre-modelar: no implementar saldo a favor ni multimoneda real (solo PEN, campo `currency` presente).
- Lógica de dominio filtrándose a la UI → casos de uso obligatorios.

### Notas de avance
- 2026-11-17: `Money` + 9 tests listos (parse, format, split, sin double).
- 2026-11-17: esquema Drift v1 (7 tablas, FK, CHECK, UNIQUE contacto/cobro, índices) + 5 tests. `payments`/`attachments`/`settlements` van en Fases 2-3.
- 2026-11-17: `AuditService` + `SpacesRepository` + `ContactsRepository` (+5 tests).
- 2026-11-17: `CollectionsRepository` + `ReceivablesRepository` (bulkCreate atómico, regla de no reducir bajo lo cobrado vía `CollectedLookup`, cancelar bloqueado con pagos) (+9 tests). Total 29 tests.
- 2026-11-17: providers de repos + UI de espacios (lista/form/detalle, estados vacío/carga/error) + Inicio provisional (+5 tests UI, 34 total). Nota: Drift real dentro de `testWidgets` se cuelga; en tests de UI sobreescribir providers de stream.
- 2026-11-17: UI de Personas (lista con búsqueda, form con validación, detalle, archivar) + FAB contextual (+3 tests UI, 37 total).
- 2026-11-17: UI de Cobros (lista buscable, form, detalle con obligaciones y total comprometido) + Asignar personas (masivo, omite existentes) + cobros en detalle de espacio (+4 tests UI, 41 total).
- 2026-11-17: historial en detalle de persona, editar importe / cancelar obligación desde UI, `docs/modelo-datos.md` y ADR 0002 (42 tests). Fase 1 funcionalmente completa.
- 2026-11-17: `flutter build apk --debug` OK tras activar core library desugaring (lo exige flutter_local_notifications). Aún sin probar en dispositivo físico.

---

## Fase 2: Cobros y abonos (núcleo funcional) — COMPLETADA

**Duración estimada**: 5 días
**Objetivo**: cuotas, pagos con verificación, anulaciones, saldos correctos, auditoría, dashboard y búsqueda.
**Complejidad**: Alto

### Requisitos previos
- Fase 1 completa

### Entregables (Definición de Done)

#### Datos / dominio
- [x] Tablas `payments`, `payment_allocations`, `attachments` (esquema v2 + migración v1→v2 verificada con SchemaVerifier)
- [x] Calculadora de saldos (§4.1): saldo, recaudado, estados derivados (`pending/partial/paid/overdue/cancelled`) — pura y testeada (`BalanceCalculator`)
- [x] Casos de uso transaccionales: registrar abono, confirmar, rechazar, anular con motivo (+ auditoría en misma transacción) — `PaymentsRepository`
- [x] Reglas: pago > saldo rechazado con mensaje; pendiente no descuenta; pagada solo con saldo confirmado 0
- [x] Plan de cuotas: generar/editar, validar suma == total; asignación de pagos a cuotas (`InstallmentPlanner`, `InstallmentsRepository`, `AllocationService` derivada y recalculable)
- [x] Adjuntos: repositorio + `image_picker` en el formulario de abono (copia a almacenamiento privado, SHA-256; cifrado real en Fase 4)

#### Frontend
- [x] Registrar abono (pocos toques: importe, fecha, método, referencia, imágenes con image_picker, confirmar ahora / por verificar)
- [x] Detalle de abono: evidencia, confirmar/rechazar/anular con motivo, historial de auditoría
- [x] Plan de cuotas (pantalla editable con validación de suma, generar iguales, quitar plan)
- [x] Detalle de cobro: avance global, participantes, saldo y estado por obligación (pagos: ver detalle de obligación)
- [x] Inicio: tarjetas por cobrar/recaudado/vencido, pagos recientes, próximos vencimientos, filtro por espacio (filtro por moneda: pendiente, solo PEN en V1)
- [x] Lista de Cobros buscable con filtros por estado/espacio (muestra espacio, avance, saldo y vencido)
- [~] FAB contextual: espacio, cobro y persona listos; "abono" se registra desde el detalle de la obligación (el FAB global no sabe a quién abonar)

#### Tests
- [x] Unit: calculadora, audit trail de anulación, rechazo de exceso, revalidación al confirmar, cuotas con suma exacta y fechas de fin de mes
- [x] Integración (repositorio): flujo 1-5 de §12 (S/120 → 30, 40 pendiente, confirmar, 50 → paid)
- [x] Integración: campaña de 20 participantes, balance = suma de obligaciones (`test/integration/spec_flows_test.dart`, también §12.10 persistencia y auditoría)

#### Documentación
- [x] ADR 0003: saldo derivado vs almacenado; modelo de asignaciones
- [x] Guía de reglas de negocio en `docs/reglas-de-negocio.md`

### Posibles obstáculos
- Consistencia saldo/estado → derivar siempre, nunca guardar `status` de obligación manualmente.
- Rendimiento con 20+ participantes: consultas agregadas con índices, no N+1.
- UX de registro de abono con demasiados campos → valores por defecto (fecha hoy, método último usado).

### Notas de avance
-

---

## Fase 3: Documentos y rendiciones — COMPLETADA (pendiente solo prueba manual de compartir en dispositivo)

**Duración estimada**: 4 días
**Objetivo**: PDFs de estado de cuenta y de campaña, compartir por sistema, fondos de terceros y rendiciones.
**Complejidad**: Medio

### Requisitos previos
- Fase 2 completa (saldos fiables)

### Entregables (Definición de Done)

#### Datos / dominio
- [x] Tabla `settlements`; caso de uso registrar/anular rendición (auditado)
- [x] `por_entregar = recaudado - entregas_confirmadas`; bloquear entregas > recaudado
- [x] Rendición no altera deudas de participantes

#### PDF / compartir
- [x] `core/pdf`: estado de cuenta individual (cabecera, movimientos confirmados, saldo, sección separada de pendientes, nota no tributaria, A4 con paginación)
- [x] Opciones: teléfono, notas internas, cuotas, pendientes y comprobantes (redimensionados a 800 px, JPEG)
- [x] Reporte de campaña (comprometido/recaudado/pendiente/vencido; recaudado/entregado/por entregar para terceros)
- [x] Compartir con `share_plus` (hoja nativa/WhatsApp) + advertencia de datos personales

#### Frontend
- [x] Pantalla Rendiciones y bloque recaudado/entregado/por entregar en detalle de cobro
- [x] Pantalla Reportes con filtros (rango de vencimiento, espacio, cobro, persona, estado) y vista previa PDF

#### Tests
- [x] Unit: rendición no altera deuda; control de exceso
- [x] Integración: flujo 6-7 y 9 de §12
- [x] Golden/estructura de PDF (saldo cero con tres movimientos)

#### Documentación
- [x] Guía de reportes y campos del PDF

### Posibles obstáculos
- Tablas PDF largas y fuentes con tildes/«S/» → embeber fuente (Poppins/Noto) en `pdf`.
- Tamaño del PDF con imágenes adjuntas → redimensionar.

### Notas de avance
- 2026-11-17: esquema v3 + `SettlementsRepository` (6 tests), UI Rendiciones, bloque en detalle de cobro; anular pago bloqueado si deja lo entregado sin respaldo.
- 2026-11-17: `core/pdf` (estado de cuenta, reporte de cobro; Helvetica Latin-1 con `pdfSafe`), `ReportsRepository`, vista previa + compartir con advertencia, pantalla Reportes (+5 tests PDF). 138 tests, analyze limpio. Flujo 7 (hoja nativa) requiere prueba manual en dispositivo.
- 2026-11-17: comprobantes en PDF (paquete `image`, reducción a 800 px) con opción en la vista previa (+1 test).

---

## Fase 4: Seguridad y cierre V1 — PENDIENTE

**Duración estimada**: 5 días
**Objetivo**: PIN, biometría, cifrado de BD/adjuntos, respaldo/restauración, notificaciones y pruebas integrales.
**Complejidad**: Alto

### Requisitos previos
- Fases 1-3 completas

### Entregables (Definición de Done)

#### Seguridad
- [ ] Decisión documentada (ADR) y migración a SQLite cifrado (SQLCipher validado con Drift); clave en `flutter_secure_storage`
- [ ] PIN con derivación robusta (KDF) + sal; biometría con `local_auth`
- [ ] Bloqueo al volver de segundo plano, período de gracia configurable, FLAG_SECURE opcional
- [ ] Cifrado de adjuntos en disco
- [ ] Onboarding: explicación, PIN, biometría opcional, primer espacio

#### Respaldo
- [ ] Exportar paquete cifrado (BD + adjuntos) con AEAD, clave desde frase de recuperación (no solo PIN)
- [ ] Restaurar: validar integridad/versión/espacio, confirmación explícita, respaldo previo y rollback ante fallo

#### Notificaciones
- [ ] Recordatorios locales de cuotas por vencer/vencidas, permisos Android 13+, zona horaria, reprogramar tras reinicio y tras altas/cambios/anulaciones
- [ ] Contenido oculto en pantalla bloqueada por defecto

#### Ajustes / calidad
- [ ] Pantalla Ajustes completa (perfil local, PIN/biometría, notificaciones, respaldos, privacidad)
- [ ] Accesibilidad (contraste, tamaños, semántica) y revisión de estados vacío/error/cancelación

#### Tests
- [ ] Unit: KDF/PIN, cifrado/descifrado, verificación de integridad
- [ ] Integración: flujos 10-12 de §12 (reabrir app, backup→restaurar con hashes, migración de esquema)
- [ ] Prueba en dispositivo Android físico offline (criterio MVP)

#### Documentación
- [ ] Modelo de amenazas y política de privacidad (borrador)
- [ ] Guía de respaldo/restauración para el usuario

### Posibles obstáculos
- Compatibilidad SQLCipher/Drift y versión de plugins → spike de 0.5 día al inicio de la fase.
- Pérdida de la frase de recuperación → advertencia clara en UI; sin recuperación posible.
- Restauración fallida a medias → restaurar a ubicación temporal y swap atómico.

### Notas de avance
-

---

## Fase 5: Distribución — PENDIENTE

**Duración estimada**: 3 días
**Objetivo**: build release firmado, assets finales y material legal para publicar.
**Complejidad**: Medio

### Requisitos previos
- Fase 4 completa; MVP aceptado en dispositivo físico

### Entregables (Definición de Done)
- [ ] Ícono adaptativo final (formas sólidas, sin texto pequeño; vectorial) y splash revisado
- [ ] Permisos mínimos en `AndroidManifest` auditados
- [ ] Firma Android (keystore fuera del repo; `key.properties` ignorado) y build reproducible
- [ ] `scripts/build_release.sh` → APK/AAB ofuscado; símbolos respaldados
- [ ] Verificar actualización automática (in_app_update) en Play: instalar vN desde Internal testing, subir vN+1 (subir `versionCode`) y comprobar descarga flexible + aviso REINICIAR
- [ ] Política de privacidad publicada y enlazada en Ajustes (mencionar consulta a Google Play)
- [ ] Validar marca «Cuotiva» (Indecopi, Play Store, dominios)
- [ ] Ficha de Play Store (capturas, descripción, eslogan «Cada cuota cuenta»)
- [ ] Tests: `flutter analyze` + `flutter test` locales verdes; smoke del AAB release en dispositivo
- [x] `CHANGELOG.md` v1.0.0 y README final

### Posibles obstáculos
- Nombre ya registrado → plan B de nombre antes de gastar en assets.
- Ofuscación rompe reflexión/plugins → probar el release, no solo debug.

### Notas de avance
-

---

## Timeline Total
- Fase 0: 2 días
- Fase 1: 4 días
- Fase 2: 5 días
- Fase 3: 4 días
- Fase 4: 5 días
- Fase 5: 3 días
**TOTAL: ~23 días de trabajo (~5 semanas)**

## Riesgos Identificados
1. Errores en saldos/estados (núcleo financiero) → tests de dinero antes de reportes; saldo siempre derivado; auditoría transaccional.
2. Cifrado SQLite con Drift no trivial → spike temprano; abstraer `QueryExecutor` desde Fase 0.
3. Pérdida de datos en restauración/migración → restauración atómica con respaldo previo; tests de migración por versión.
4. Conflictos de versiones de plugins (ya hubo win32) → fijar versiones; revisar `flutter pub outdated` por fase.
5. Datos personales en PDFs compartidos → advertencia y opciones de omitir teléfono/notas.
6. Disponibilidad de marca → validar antes de Fase 5.

## Commits/PRs sugeridos por fase
- F0: `chore: scaffold + tema`, `chore: drift + lints + CI`, `docs: README/CHANGELOG/ADR`
- F1: `feat(money): Money + tests`, `feat(db): esquema v1 + repos`, `feat(spaces/contacts)`, `feat(collections/receivables)`
- F2: `feat(payments): dominio + saldos + tests`, `feat(installments)`, `feat(payments-ui)`, `feat(dashboard)`
- F3: `feat(settlements)`, `feat(pdf): estado de cuenta`, `feat(reports): campaña + compartir`
- F4: `feat(security): PIN/biometría`, `feat(db): cifrado`, `feat(backup)`, `feat(notifications)`, `feat(onboarding)`
- F5: `chore(release): firma + AAB`, `docs: privacidad`, `chore: icono final`

## Historial de Cambios
- 2026-11-17: Plan creado con 6 fases desde CUOTIVA_SPEC.md §13. Fase 0 parcialmente completada por el scaffold.
- 2026-11-17: Fase 0 completada; Fase 1 iniciada (Money).
- 2026-11-17: Fase 1 completada (APK debug compila).
- 2026-11-17: `AppUpdateService` (in_app_update, actualización flexible de Play al arrancar + botón manual en Ajustes). Solo funciona con instalación desde Play.
- 2026-11-17: Fase 2 iniciada: esquema v2 (payments, payment_allocations, attachments) con migración probada (`drift_schemas/`, `test/drift/`). Al cambiar el esquema: `dart run drift_dev schema dump` + `schema generate`.
- 2026-11-17: `BalanceCalculator` (saldo, estados derivados, totales de cobro) con 17 tests.
- 2026-11-17: `PaymentsRepository` (register/confirm/reject/void, exceso rechazado, revalidación al confirmar, auditoría transaccional) + 12 tests; `CollectedLookup` conectado a pagos confirmados.
- 2026-11-17: `AttachmentsRepository` (+7 tests, dependencia `crypto`).
- 2026-11-17: Plan de cuotas + `AllocationService` (FIFO, derivado) + guard de importe con plan; `PaymentsRepository` reasigna al confirmar/anular. Capa de dominio/datos de Fase 2 completa; falta toda la UI de abonos, dashboard y búsqueda.
- 2026-11-17: UI: detalle de obligación (saldo, plan, abonos), formulario de abono con comprobantes, totales/estados en detalle de cobro; `BalancesRepository` (lotes + totales globales). Falta detalle de abono, pantalla de plan, dashboard, búsqueda.
- 2026-11-17: Detalle de abono (confirmar/rechazar/anular con motivo, comprobantes, historial) + pantalla de plan de cuotas. Nota test: los widgets no deben leer repositorios en `build` (abre la DB real); leerlos en callbacks.
- 2026-11-17: Inicio con datos reales (saldo por cobrar, recaudado, vencido, avance, próximos vencimientos con `upcomingDue`, pagos recientes, filtro por espacio) + 5 tests de dominio y 4 de UI.
- 2026-11-17: Fase 2 completada: lista de Cobros con filtros, tests de integración §12 (1-5, 8, 10), ADR 0003 y guía de reglas. 127 tests; APK debug compila. Pendiente de validar en dispositivo físico.
