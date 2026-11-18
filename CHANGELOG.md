# Changelog

## [Sin publicar]

## [1.1.0+2] - 2026-11-17
### Añadido
- Botón «Ir al inicio» en las pantallas abiertas: cierra todas las ventanas apiladas de una vez.
- PDF: nombre de archivo con el título del cobro y la persona (`estado-de-cuenta_cobro_persona.pdf`) y logo de Cuotiva en el encabezado.
- Abonos dirigidos a una cuota: tocar la cuota, selector «Aplicar a» y reparto automático del resto (esquema v4, `payments.installment_id`).
- Fase 4: base cifrada (SQLCipher), PIN + biometría + bloqueo, comprobantes cifrados, respaldo/restauración cifrados, recordatorios de cuotas, onboarding.
- Fase 3: esquema v3 (`settlements`), rendiciones de fondos de terceros (recaudado/entregado/por entregar), PDF de estado de cuenta y de reporte de cobro, compartir por hoja nativa, pantalla Reportes con filtros.
- Actualización automática con Google Play (in_app_update): chequeo al iniciar y botón en Ajustes.
- Núcleo de datos: Money, esquema Drift v1, UI de espacios, personas, cobros y obligaciones.
- Scaffold inicial: estructura por features, tema Material 3, GoRouter, Riverpod, Drift base.
