# CUOTIVA — Especificación funcional y técnica

**Versión:** 1.0 (MVP)  
**Fecha:** 16 de noviembre de 2026  
**Plataforma:** Android mediante Flutter  
**Modalidad:** Local-first, mono-usuario, sin panel web ni backend en la V1  
**Estado de marca:** Cuotiva es un nombre de trabajo; validar disponibilidad en Indecopi, tiendas y dominios antes de comercializar.  
**Eslogan propuesto:** «Cada cuota cuenta».

## 1. Visión de producto

Cuotiva es una aplicación móvil para registrar, controlar y dar seguimiento al dinero **por cobrar** en distintos contextos: familia, negocio, colegio, capilla, trabajo y eventos. Permite administrar ventas al crédito, préstamos, cuotas de una actividad, colectas y cobros por encargo, con abonos parciales, imágenes de comprobantes, saldos y estados de cuenta PDF compartibles por WhatsApp u otras apps.

**Principio de producto:** una sola interfaz y un solo motor de cobros sirven tanto para una deuda de una persona como para una campaña con decenas de participantes.

### 1.1 Casos de uso iniciales

1. **Venta al crédito:** una comerciante vende un buzo a S/ 120; el cliente abona S/ 30, luego S/ 40 y finalmente S/ 50.
2. **Trajes de colegio:** se crea el cobro «Trajes de promoción» y se asigna S/ 150 a cada padre; se registra y consulta el avance individual y global.
3. **Pasajes para un evento religioso:** se registra una campaña de pasajes, participantes y pagos; el administrador puede distinguir fondos recaudados para entregar a un tercero.
4. **Préstamo familiar:** se registra un préstamo de S/ 500 a una persona que devuelve en cuotas variables.
5. **Cobro libre:** una persona debe dinero sin cuotas programadas; registra pagos a demanda.

## 2. Alcance y exclusiones de V1

### Incluido

- Gestión de **espacios** (ámbitos): Familia, Negocio, Colegio, Capilla, Trabajo, Eventos u otros; nombre, color, ícono y descripción.
- Agenda global de contactos; un contacto puede aparecer en varios espacios y cobros sin duplicarse.
- Campañas/conceptos de cobro individuales o colectivos.
- Obligaciones por persona, con monto, moneda, vencimiento opcional, concepto y notas.
- Cuotas programadas opcionales; abonos libres o vinculados a cuotas.
- Registro de pagos con fecha, monto, método, referencia, notas y hasta varias imágenes adjuntas.
- Validación manual de comprobantes; un adjunto de Yape/Plin **no equivale por sí solo a pago confirmado**.
- Saldos y estados calculados a partir de pagos confirmados y ajustes auditados.
- Panel global y por espacio/campaña; búsqueda y filtros.
- Estados de cuenta individuales y resumen de cobros en PDF.
- Compartir PDF por el selector del sistema (incluido WhatsApp, si está instalado).
- Acceso privado con PIN y desbloqueo biométrico cuando el equipo lo soporte.
- Exportación y restauración de respaldo cifrado, con verificación de integridad.
- Notificaciones locales de vencimiento, con permiso del usuario.
- Soporte inicial para soles peruanos (PEN); modelo listo para monedas adicionales.
- Registro opcional de entregas/rendiciones de dinero recaudado para terceros.

### No incluido

- Multiusuario, roles, inicio de sesión remoto, portal público o sitio web.
- Integraciones de consulta automática a Yape, Plin o bancos.
- Envío automático de WhatsApp, lectura de chats o mensajería masiva.
- Emisión de comprobantes tributarios SUNAT.
- Motor de intereses, mora compleja, scoring crediticio o contabilidad de doble partida.
- Sincronización en tiempo real o backend en producción.

## 3. Vocabulario de dominio

- **Espacio (`space`):** contexto organizativo: familia, negocio, colegio, etc.
- **Cobro / campaña (`collection`):** concepto agrupador, por ejemplo «Trajes 2027», «Pasaje a misa» o «Préstamo a Rosa».
- **Obligación (`receivable`):** importe que debe una persona concreta dentro de un cobro/campaña.
- **Cuota (`installment`):** fecha e importe esperado de parte de una obligación; es opcional.
- **Pago / abono (`payment`):** registro de dinero recibido; puede estar pendiente, confirmado o anulado.
- **Aplicación de pago (`payment_allocation`):** cantidad de un pago que se aplica a una cuota u obligación.
- **Rendición / entrega (`settlement`):** transferencia del dinero recaudado a su destinatario; no reduce las deudas de los participantes.

## 4. Reglas de negocio

### 4.1 Montos

- Almacenar importes monetarios en **enteros de unidad mínima** (céntimos para PEN) y código ISO 4217; no emplear `double` para cálculos de dinero.
- `saldo_obligación = importe_original + ajustes_de_cargo - descuentos_confirmados - pagos_confirmados_aplicados`.
- `recaudado = suma de pagos confirmados`, sin contar pagos pendientes, rechazados o anulados.
- No mezclar monedas en un total consolidado sin conversión explícita y trazable.
- Redondeo y moneda deben definirse en un servicio centralizado.

### 4.2 Estados

- **Obligación:** `pending`, `partial`, `paid`, `overdue`, `cancelled`. `overdue` es preferentemente estado derivado de vencimiento y saldo, no dato que deba mantenerse a mano.
- **Pago:** `pending_verification`, `confirmed`, `rejected`, `voided`.
- Un pago confirmado puede revertirse con una **anulación registrada**, no por borrado silencioso.
- Una obligación se marca pagada solo si el saldo confirmado es cero; nunca mediante un switch aislado.
- No admitir un pago superior al saldo salvo mediante flujo explícito de **saldo a favor** (fuera de MVP). En V1 impedir el exceso y explicar el motivo.
- Al editar una obligación con pagos, impedir reducir el importe por debajo de lo ya cobrado salvo operación de ajuste supervisada y auditada.
- Cuotas suman el total de la obligación si se usa plan cerrado; un plan libre puede operar sin cuotas.

### 4.3 Recaudaciones por encargo

Una campaña puede marcarse `funds_ownership = self | third_party`. En campañas `third_party`:

- Mostrar por separado **recaudado**, **entregado/rendido** y **por entregar**.
- `por_entregar = total_pagos_confirmados - entregas_confirmadas`, con control de entregas que excedan lo recaudado.
- Los pagos de participantes y las entregas al organizador son movimientos distintos.
- Los reportes deben dejar claro que el dinero recaudado no necesariamente es ingreso personal.

### 4.4 Contactos y privacidad

- Contactos globales con nombre obligatorio; teléfono, correo y observaciones opcionales.
- Permitir registrar contactos sin conceder acceso al directorio; importación de contactos del dispositivo opcional y explícita.
- Teléfono normalizado cuando se registre, sin obligar a usar WhatsApp.
- Los PDFs de estado de cuenta contienen datos personales: advertir antes de compartir y ofrecer omitir teléfono/notas privadas.

## 5. Navegación y pantallas

Barra inferior: **Inicio | Cobros | Personas | Reportes**. Botón flotante contextual para añadir espacio, cobro, persona o abono.

1. **Onboarding:** explicación breve, creación de PIN, configuración opcional de biometría y primer espacio.
2. **Inicio:** tarjetas de total por cobrar, recaudado, vencido y pagos recientes; filtro por espacio y moneda; próximos vencimientos.
3. **Mis espacios:** lista con color/ícono, conteos y saldos; crear, editar, archivar.
4. **Detalle de espacio:** campañas/cobros pertenecientes, contactos vinculados y resumen.
5. **Cobros:** lista buscable con estado, monto, pendiente, fechas y espacio.
6. **Crear/editar cobro:** título, espacio, tipo (venta a crédito, préstamo, recaudación, servicio, otros), beneficiario de fondos, fechas y notas.
7. **Detalle de cobro:** avance global, participantes, obligaciones, pagos y rendiciones.
8. **Personas:** agenda global y detalle con historial de obligaciones y pagos.
9. **Crear obligación:** contacto, campaña, importe, vencimiento y modalidad libre/programada.
10. **Plan de cuotas:** número, fechas e importes editables con validación de suma.
11. **Registrar abono:** persona/obligación, importe, fecha/hora, medio de pago, referencia, adjuntos y estado de verificación.
12. **Detalle de abono:** evidencia, datos, confirmar, rechazar, anular con motivo y auditoría.
13. **Rendiciones:** listado de entregas y saldo por rendir para cobros de terceros.
14. **Reportes:** filtros por rango, espacio, campaña, persona y estado; PDF.
15. **Ajustes:** perfil local, PIN/biometría, notificaciones, respaldos, restauración y política de privacidad.

### 5.1 Flujo mínimo para un cobro colectivo

Crear espacio «Colegio» → crear campaña «Trajes 2027» → añadir participantes → asignar obligación de S/ 150 a cada persona → recibir abono → guardar fotografía de Yape → confirmar recepción manual → recalcular saldo → compartir estado de cuenta PDF.

### 5.2 Flujo mínimo para préstamo

Seleccionar espacio «Familia» → crear cobro «Préstamo a María» → asociar contacto María → obligación S/ 500, sin cuotas o con calendario → registrar cada abono → ver saldo e historial → exportar PDF.

## 6. Diseño visual e identidad

**Nombre de trabajo:** Cuotiva.  
**Concepto gráfico:** portapapeles/lista de cuotas con marcas de verificación y monedas; moderno, humano, legible a 48 px.  
**Color primario:** violeta `#6D28D9`.  
**Color secundario:** violeta oscuro `#4C1D95`.  
**Acento de éxito:** verde menta `#34D399`.  
**Acento cálido:** amarillo `#FBBF24`.  
**Superficie clara:** `#FAF8FF` y texto `#201A2E`.

Usar Material 3 y definir tema claro desde V1; soportar modo oscuro como mejora posterior. El ícono final debe simplificarse a formas sólidas, sin texto pequeño, para Adaptive Icons Android. La ilustración de marca provista es referencia visual, no logo vectorial definitivo.

## 7. Arquitectura Flutter

### Stack

- Flutter (canal stable al inicio del proyecto); Dart.
- Riverpod para estado e inyección de dependencias.
- GoRouter para navegación.
- Drift + SQLite para persistencia local y migraciones.
- `freezed`/`json_serializable` cuando aporten valor en DTO y estados.
- `image_picker` para capturas/galería; copia de adjuntos a almacenamiento privado de la aplicación.
- `pdf` + `printing` para generación/visualización.
- `share_plus` para compartir mediante hoja del sistema.
- `local_auth` para biometría; credencial PIN con derivación robusta y sal aleatoria.
- `flutter_secure_storage` para secretos/llaves según plataforma.
- `flutter_local_notifications` para avisos locales.

**Seguridad:** seleccionar una solución de cifrado de SQLite compatible y mantenida (por ejemplo una integración SQLCipher validada para Drift) antes de producción. No asumir que SQLite estándar cifra datos. Los adjuntos sensibles y respaldos deben cifrarse también. Comprobar la disponibilidad real de cada plugin y sus versiones al implementar.

### Capas y organización sugerida

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
    security/
    money/
    errors/
    pdf/
    backup/
    notifications/
    widgets/
  features/
    onboarding/
    dashboard/
    spaces/
    contacts/
    collections/
    receivables/
    installments/
    payments/
    settlements/
    reports/
    settings/
  main.dart
```

Cada feature organiza `domain/`, `data/` y `presentation/`. La UI nunca ejecuta SQL directamente; interactúa mediante controladores/casos de uso. Las escrituras compuestas se ejecutan en transacciones SQLite.

## 8. Modelo de datos propuesto

Todas las tablas llevan `id UUID`, `created_at`, `updated_at`. Añadir `archived_at`/`deleted_at` cuando corresponda, evitando borrados de información con movimientos financieros.

| Tabla | Campos principales | Observaciones |
|---|---|---|
| `spaces` | name, type, color, icon, description, archived_at | Ámbitos personalizables |
| `contacts` | display_name, phone, email, notes, archived_at | Una ficha por persona |
| `collections` | space_id, title, kind, funds_ownership, due_at, notes, archived_at | Campaña/concepto |
| `receivables` | collection_id, contact_id, principal_minor, currency, due_at, notes, cancelled_at | Deuda individual |
| `installments` | receivable_id, sequence, due_at, amount_minor | Opcional |
| `payments` | receivable_id, amount_minor, currency, occurred_at, method, status, reference, notes, verified_at, voided_at | Abonos y validación |
| `payment_allocations` | payment_id, installment_id, amount_minor | Distribución a cuotas; si no hay plan, saldo directo en receivable |
| `attachments` | payment_id, relative_path, mime_type, byte_size, checksum, encrypted | Comprobantes privados |
| `settlements` | collection_id, amount_minor, currency, occurred_at, status, recipient_name, notes | Entrega de fondos |
| `audit_logs` | entity_type, entity_id, action, old_values_json, new_values_json, occurred_at | Cambios críticos |
| `app_settings` | key, value | Preferencias no secretas |

### Integridad e índices

- FK explícitas; `PRAGMA foreign_keys=ON`.
- Índices en `collections.space_id`, `receivables.collection_id`, `receivables.contact_id`, `payments.receivable_id`, `payments.occurred_at`, `installments.due_at`.
- Validar montos positivos, estados válidos y moneda consistente en la capa de dominio y con restricciones DB donde sea posible.
- La suma de asignaciones de un pago no puede superar el importe del pago confirmado.
- Registrar abonos/confirmaciones/anulaciones en una única transacción que incluya la auditoría.
- Definir migraciones con versionado y pruebas de actualización entre esquemas.

## 9. Reportes y PDF

### Estado de cuenta individual

Cabecera Cuotiva; espacio; concepto; persona; moneda; importe original; tabla de movimientos con fecha, método, monto y referencia opcional; total confirmado; saldo pendiente; fecha de emisión; nota «Este documento es un estado de cuenta informativo, no un comprobante tributario».

Opciones: incluir/excluir teléfono, adjuntos, notas internas y detalle de cuotas. Diseño A4, paginación y manejo de tablas largas. Si hay pagos pendientes de verificación, mostrarlos **en una sección separada** sin descontarlos del saldo.

### Reporte de campaña

Participantes, comprometido, recaudado, pendiente, vencido; para fondos de terceros, recaudado/entregado/por entregar. Exportar a PDF; exportación CSV opcional para V1.1.

### WhatsApp

Compartir archivo PDF a través del intent/sheet nativo de Android; no depender de APIs de WhatsApp ni automatización no autorizada.

## 10. Respaldo, restauración y seguridad

- Los datos deben persistir offline y sobrevivir al reinicio de la app/dispositivo.
- Respaldo manual en paquete cifrado con base de datos y adjuntos; no incluir secretos en texto plano.
- Cifrado autenticado moderno; clave derivada de frase de recuperación elegida por usuario. **No depender exclusivamente del PIN corto** para cifrar un backup portable.
- Validar integridad, versión y espacio disponible antes de importar.
- Restauración con confirmación explícita; ofrecer respaldo previo de la base actual y estrategia de recuperación ante fallos.
- Bloqueo al volver del segundo plano, período de gracia configurable y evitar capturas en pantallas sensibles si el usuario lo activa.
- Ocultar montos y nombres de notificaciones en pantalla bloqueada por defecto.
- No enviar datos a servicios externos sin explicación y consentimiento.

## 11. Notificaciones

- Recordatorio local de cuotas próximas a vencer y vencidas, opcional.
- Programación y reprogramación tras altas, cambios y anulaciones.
- Manejar permisos Android recientes, zona horaria y reinicio del dispositivo de forma compatible con las APIs disponibles.
- Ninguna notificación automática se envía al deudor; el administrador decide si comparte un recordatorio.

## 12. Pruebas y criterios de aceptación

### Pruebas unitarias

- Recaudado y saldo con múltiples pagos confirmados.
- Pago pendiente con comprobante no descuenta saldo.
- Anulación de pago restaura saldo y deja audit trail.
- Rechazo a pagos mayores que el saldo.
- Plan de cuotas con suma exacta y asignaciones coherentes.
- Rendición a un tercero no altera deuda de participantes.
- Contacto compartido entre espacios y campañas.
- Cálculo de vencimiento con fechas límites.
- Cálculo monetario exacto con importes en céntimos.

### Pruebas de integración / UI

1. Crear espacio «Negocio», registrar cliente y venta a crédito S/ 120.
2. Registrar abono confirmado S/ 30 → saldo S/ 90.
3. Registrar abono pendiente S/ 40 con imagen → saldo sigue S/ 90.
4. Confirmar abono S/ 40 → saldo S/ 50.
5. Registrar S/ 50 → estado `paid`, saldo S/ 0.
6. Generar PDF: figuran los tres movimientos confirmados y saldo cero.
7. Compartir PDF por hoja nativa.
8. Crear campaña para 20 participantes; balance global igual a suma de obligaciones.
9. Entregar S/ 500 al organizador; actualizar `por_entregar`, no `por_cobrar`.
10. Cerrar/reabrir app; conservar datos e imágenes.
11. Exportar respaldo cifrado, reinstalar en entorno de prueba, restaurar y comprobar conteos y hashes.
12. Actualizar app con migración de esquema; conservar historial.

### Definición de terminado (MVP)

MVP aceptado cuando todos los flujos anteriores funcionen offline en un dispositivo Android físico; no haya operaciones financieras sin auditoría; PDF y respaldo/restauración operen correctamente; y los tests críticos estén automatizados.

## 13. Plan de implementación recomendado

### Fase 0 — Base del proyecto

Configurar Flutter, lint, análisis estático, tema Material 3, GoRouter, Riverpod, Drift, convenciones, CI de tests, localización española y estructura de carpetas. Crear `README.md`, `CHANGELOG.md` y archivo de decisiones arquitectónicas.

### Fase 1 — Núcleo de datos

Espacios, contactos, campañas, obligaciones; migraciones, relaciones y repositorios. Implementar casos de uso y pruebas sin UI compleja.

### Fase 2 — Cobros y abonos

Cuotas, pagos, validación de comprobantes, anulaciones y auditoría; paneles y búsquedas. Este es el núcleo funcional del producto.

### Fase 3 — Documentos y rendiciones

PDF por persona/campaña, compartir por Android, fondos de terceros y rendiciones; consistencia de saldos.

### Fase 4 — Seguridad y cierre V1

PIN, biometría, almacenamiento cifrado, backup/restauración, notificaciones, accesibilidad y pruebas integrales.

### Fase 5 — Distribución

Adaptive icon, splash, permisos mínimos, firma Android, build reproducible y APK/AAB release. Preparar política de privacidad y revisar disponibilidad de marca.

## 14. Comandos y calidad del proyecto

El repositorio debe documentar cómo ejecutar localmente:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
flutter build appbundle --release
```

Crear `run.sh` como atajo de desarrollo en Linux Ubuntu (`flutter pub get` + `flutter run`, con verificaciones básicas); no almacenar credenciales de firma en el repositorio. Preferir CI para tests/análisis y compilación release con secretos configurados de forma segura.

## 15. Evolución futura (no implementar prematuramente)

- Backup remoto cifrado y sincronización con API (posible backend Atlas).
- Multi-dispositivo con resolución de conflictos y registro de eventos idempotente.
- Multiusuario, roles y espacios compartidos.
- Pagos recurrentes, recordatorios configurables y plantillas de cobro.
- Exportaciones XLSX y conciliación manual de movimientos.
- Soporte multimoneda con reportes separados por divisa.
- Tablero para microemprendedores y cuentas por pagar como módulo independiente.

## 16. Instrucciones para el agente de desarrollo

1. Leer completamente este SPEC antes de implementar.
2. Implementar por fases y entregar funcionalidad verificable al cierre de cada una.
3. No incorporar backend, login remoto ni servicios de pago en V1.
4. Favorecer simplicidad de UX: registrar un abono confirmado debe requerir pocos toques.
5. Escribir tests para cálculos de dinero antes de construir reportes.
6. Mantener todos los textos visibles al usuario en español y preparados para internacionalización.
7. Solicitar decisiones solo ante vacíos que afecten integridad, seguridad o producto; en los demás casos usar alternativas simples y documentarlas.
8. No declarar completa una funcionalidad si no maneja errores, datos vacíos, carga, cancelación y persistencia.

---

**Cuotiva — Cada cuota cuenta.**
