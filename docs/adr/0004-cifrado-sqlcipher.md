# ADR 0004: Cifrado de la base con SQLCipher

Estado: aceptada (2026-11-17)

## Contexto
La app guarda datos financieros y personales solo en el dispositivo (§7 del spec).
Hace falta cifrado en reposo de la base sin cambiar de ORM.

## Decisión
- **SQLCipher** mediante el hook de `package:sqlite3` (`hooks.user_defines.sqlite3.source: sqlcipher`
  en `pubspec.yaml`), usado por Drift con `NativeDatabase`. Validado con spike: el motor
  reporta `cipher_version`, sin clave o con clave errónea la base no abre y el archivo
  no contiene texto plano. El APK incluye `libsqlcipher.so` (arm64, armv7, x64).
- **Clave**: 32 bytes aleatorios (`Random.secure`) guardados en `flutter_secure_storage`
  (Android Keystore) y aplicados como clave cruda (`PRAGMA key = "x'<hex>'"`), sin KDF
  interno de SQLCipher. **No se deriva del PIN**: cambiar el PIN no recifra la base y
  el PIN solo protege el acceso a la app (bloqueo), no el archivo.
- `resetOnError: false` en el almacén seguro: si el Keystore falla no se borra la clave.
- **Migración**: una base en texto plano (builds de desarrollo anteriores) se exporta con
  `sqlcipher_export`, conservando `user_version`; se mantiene una copia hasta verificar
  que la nueva abre y se restaura si falla.

## Consecuencias
- Si se pierde la clave del Keystore (p. ej. reinstalación o borrado de datos) la base
  es irrecuperable: la copia de seguridad cifrada con frase de recuperación (ADR futuro)
  es la única vía de recuperación.
- Los respaldos no pueden depender de la clave del Keystore: se cifran aparte.
- La licencia de SQLCipher community y su enlace con OpenSSL en Android deben citarse
  en Créditos/licencias antes de publicar.
