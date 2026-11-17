# Cuotiva

*Cada cuota cuenta.*

App Android (Flutter) para controlar cobros, cuotas y abonos. Funciona **sin cuenta y sin servidores**: todo vive cifrado en el teléfono.

## Qué hace

- **Espacios y personas**: agrupa tus cobros (Familia, Negocio, Colegio…) y a quienes te deben.
- **Cobros y obligaciones**: préstamos, ventas a crédito, colectas. Los fondos pueden ser propios o de terceros.
- **Plan de cuotas**: define las cuotas y su fecha; el estado (pendiente, parcial, pagada, vencida) se calcula solo.
- **Abonos flexibles**: toca una cuota para pagarla, elige «Aplicar a» una cuota concreta, o ingresa un importe y se reparte desde la cuota más antigua.
- **Verificación de pagos**: Yape, Plin y transferencias quedan «por verificar» hasta confirmarlos; solo lo confirmado descuenta saldo.
- **Comprobantes**: adjunta fotos al abono, guardadas cifradas.
- **Rendiciones**: en cobros de terceros, controla recaudado, entregado y por entregar.
- **Reportes PDF**: estado de cuenta y reporte de cobro, para compartir.
- **Recordatorios** de cuotas por vencer.
- **Seguridad**: base de datos cifrada (SQLCipher), PIN y biometría opcionales, pantalla protegida.
- **Respaldo cifrado**: exporta y restaura con una frase de recuperación; sin ella nadie puede abrirlo.

## Principios

- Dinero siempre en enteros (céntimos), nunca `double`.
- Saldos y reparto de pagos **derivados**: se recalculan, nunca quedan inconsistentes.
- Nada se borra: los pagos se anulan con motivo y todo cambio queda auditado.
- Sin conexión: internet solo se usa para buscar actualizaciones en Google Play.

## Stack

Flutter · Riverpod · go_router · Drift + SQLCipher · flutter_secure_storage · local_auth · flutter_local_notifications · pdf/printing · Material 3.

## Estructura

```
lib/
  app/        arranque, router, bloqueo
  core/       base de datos, seguridad, respaldo, PDF, notificaciones, tema
  features/   <feature>/{data,domain,presentation}
```

Features: `spaces`, `contacts`, `collections`, `receivables`, `installments`, `payments`, `settlements`, `reports`, `settings`, `onboarding`, `dashboard`.

## Desarrollo

Requisitos: Flutter estable (Dart 3.x) y, para Android, el SDK configurado.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # código Drift
flutter analyze
flutter test
```

Atajo `run.sh`:

```bash
./run.sh            # Linux de escritorio (o Android conectado)
./run.sh android    # fuerza Android
./run.sh test       # analyze + tests
./run.sh clean      # limpia y regenera código
```

Si cambias tablas Drift, sube `schemaVersion`, añade el paso de migración y regenera los esquemas de prueba:

```bash
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/drift/generated/
```

## Release

```bash
./scripts/build_release.sh apk         # APK firmado y ofuscado
./scripts/build_release.sh appbundle   # AAB para Google Play
```

- La firma sale de `android/key.properties` (ignorado por git) y apunta al `.jks`. Sin ese archivo el build release falla a propósito. **Nunca** subas contraseñas ni el `.jks` al repositorio, y respáldalos: perderlos impide actualizar la app en Play.
- El build ofuscado genera `symbols/<versión>/`; guárdalo fuera del repo, es la única forma de leer los stack traces de esa versión.
- `applicationId`: `com.luisitomayta.cuotiva`.

## Documentación

| Documento | Contenido |
|---|---|
| [`spec/CUOTIVA_SPEC.md`](spec/CUOTIVA_SPEC.md) | Especificación funcional (fuente de verdad) |
| [`.claude/spec-plan.md`](.claude/spec-plan.md) | Plan de fases y estado |
| [`docs/modelo-datos.md`](docs/modelo-datos.md) | Modelo de datos |
| [`docs/reglas-de-negocio.md`](docs/reglas-de-negocio.md) | Reglas de negocio |
| [`docs/reportes.md`](docs/reportes.md) | Reportes PDF |
| [`docs/modelo-de-amenazas.md`](docs/modelo-de-amenazas.md) | Modelo de amenazas |
| [`docs/guia-respaldo.md`](docs/guia-respaldo.md) | Guía de respaldo y restauración |
| [`docs/politica-de-privacidad.md`](docs/politica-de-privacidad.md) | Política de privacidad |
| [`docs/adr/`](docs/adr/) | Decisiones de arquitectura |
| [`CHANGELOG.md`](CHANGELOG.md) | Historial de cambios |

Política de privacidad publicada: <https://luisitomayta.com/apps/cuotiva/politica-de-privacidad>

## Licencia

Todos los derechos reservados.
