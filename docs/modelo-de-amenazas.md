# Modelo de amenazas (V1)

Cuotiva es local-first, mono-usuario, sin backend ni cuentas.

## Activos
Datos de cobros y personas (nombres, teléfonos, montos), comprobantes de pago (imágenes),
historial de auditoría, respaldos exportados.

## Controles
| Control | Detalle |
|---|---|
| Base de datos | SQLCipher (AES-256). Clave aleatoria de 32 bytes en Android Keystore (`flutter_secure_storage`, `resetOnError: false`). ADR 0004. |
| Comprobantes | AES-256-GCM por archivo; subclave derivada de la clave de la BD; AAD = id del adjunto (no se pueden intercambiar archivos). |
| PIN | 4–8 dígitos; PBKDF2-HMAC-SHA256 150 000 it. con sal de 16 bytes; bloqueo escalonado (5 fallos → 30 s … 15 min); persiste entre reinicios. |
| Biometría | `local_auth` (solo biométrica); el PIN siempre disponible como alternativa. |
| Bloqueo | Al abrir y al volver de segundo plano tras el periodo de gracia (0 s/30 s/1 min/5 min). |
| Pantalla | FLAG_SECURE opcional (sin capturas ni vista previa en recientes). |
| Respaldo | ZIP cifrado con AES-256-GCM; clave PBKDF2 300 000 it. de una frase de recuperación; cabecera autenticada (AAD). No incluye PIN ni claves del dispositivo. |
| Restauración | Valida sobre, hashes SHA-256, versión de esquema, integridad SQLite y conteos; no toca datos hasta confirmar; copia previa y reversión. |
| Notificaciones | Contenido «privado» en pantalla bloqueada por defecto. |

## Amenazas y cobertura
- **Teléfono perdido/robado con pantalla bloqueada**: base y comprobantes cifrados; clave en Keystore. Cubierto.
- **Teléfono desbloqueado en manos ajenas**: PIN/biometría de la app + bloqueo por segundo plano. Cubierto.
- **Fuerza bruta del PIN en la app**: bloqueo escalonado. Limitación: un atacante con acceso root al almacén seguro podría borrar el contador; el PIN protege el acceso a la UI, no el cifrado (la clave de la BD no depende del PIN).
- **Archivo de respaldo filtrado**: depende de la fortaleza de la frase (mín. 12 caracteres; se ofrece generar una de ≈125 bits). Sin la frase no hay recuperación.
- **Pérdida del Keystore** (reinstalación, borrado de datos): datos irrecuperables sin respaldo. Mitigación: respaldos periódicos.
- **Dispositivo con root/malware**: fuera de alcance.
- **Capturas / apps recientes**: mitigado con FLAG_SECURE opcional.
- **PDF compartidos**: contienen datos personales; se advierte antes de compartir y se puede omitir teléfono y notas internas.

## Fuera de alcance V1
Sincronización multi-dispositivo, multiusuario, almacenamiento en la nube propio, ofuscación anti-tamper.
