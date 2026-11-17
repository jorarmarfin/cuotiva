# Reportes y PDF

## Estado de cuenta individual (una obligación)
Se abre desde el detalle de la obligación (icono PDF) o desde **Reportes**.

Contenido: cabecera Cuotiva, espacio, persona, concepto, moneda, importe original,
estado, movimientos **confirmados** (fecha, método, referencia, importe), total
confirmado, saldo pendiente, fecha de emisión y la nota «Este documento es un estado
de cuenta informativo, no un comprobante tributario». A4 con paginación.

Opciones (chips en la vista previa):

| Opción | Por defecto | Efecto |
|---|---|---|
| Teléfono | no | Muestra el teléfono de la persona |
| Notas internas | no | Muestra las notas de la obligación |
| Cuotas | sí | Tabla de cuotas con lo pagado en cada una |
| Pendientes | sí | Sección aparte «Pendientes de verificación (no descuentan saldo)» |

Los pagos rechazados y anulados nunca aparecen.

## Reporte de cobro (campaña)
Desde el detalle del cobro o desde Reportes con un cobro filtrado. Muestra
participantes, comprometido, recaudado, pendiente, vencido y la tabla por persona.
Si el cobro es de **fondos de terceros** añade recaudado / entregado / por entregar y
la lista de entregas confirmadas.

## Rendiciones
`por_entregar = recaudado_confirmado − entregas_confirmadas`.
- Solo cobros con `funds_ownership = third_party`.
- Una entrega no puede exceder lo pendiente por entregar.
- Anular una entrega exige motivo y queda auditada (no se borra).
- Anular un pago confirmado se bloquea si dejaría lo recaudado por debajo de lo ya entregado.
- Las rendiciones no modifican obligaciones, pagos ni saldos de participantes.

## Compartir
`share_plus` abre la hoja nativa de Android (WhatsApp u otras apps). Antes se muestra
una advertencia de datos personales. No hay integración con APIs de mensajería.

## Fuentes
Se usa Helvetica base del paquete `pdf` (cubre Latin-1: tildes, ñ, «S/»). Los caracteres
fuera de ese rango (emojis, etc.) se sustituyen por `?` (`core/pdf/pdf_text.dart`).
Pendiente: embeber una fuente TTF si se necesitan más alfabetos.

## Filtros de Reportes
Espacio, cobro, persona (texto), estado (derivado) y rango de vencimiento. Se
aplican en memoria sobre las obligaciones activas.
