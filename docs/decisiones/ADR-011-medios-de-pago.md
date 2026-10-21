# ADR-011 — Medios de pago de la v1: tarjeta y pago móvil verificado manualmente

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Dominio / Pagos

---

## Contexto

El negocio, en Chiclayo, recibe pagos por **Yape**, **Plin** y **transferencia bancaria** además de tarjeta. Los clientes exigen pagar así, y el modelo de negocio no puede exigir tarjeta a todos. Pero el pago móvil es **manual**: el seller debe ver el comprobante en su app bancaria y confirmarlo.

## Decisión

En la v1 hay **dos vías de pago**, con flujos distintos:

### Vía 1 — Tarjeta (automática, con pasarela)

```
Cliente → Checkout → pasarela (hosted/tokenizada) → webhook → sp_confirmar_pago
```

- El estado del pago lo confirma **la pasarela**, no un humano.
- El webhook se valida por firma.
- El pedido avanza a `PAGADO` de forma automática.

### Vía 2 — Yape / Plin / Transferencia (verificación manual)

```
Cliente → Checkout → elige método y sube/indica evidencia → genera QR o muestra datos de cuenta
       → pedido en PENDIENTE_PAGO → PAGO_POR_VERIFICAR
       → Seller ve la evidencia en el panel → verifica en su app bancaria → Aprueba
       → sp_registrar_pago_manual → pedido a PAGADO
```

**El pedido no avanza por sí solo.** Requiere la acción explícita del vendedor.

### Tabla de medios de pago

| `metodo_pago` | Automático | Verificación |
|---|:---:|---|
| `TARJETA` | Sí | Firma del webhook |
| `YAPE` | No | Manual del vendedor |
| `PLIN` | No | Manual del vendedor |
| `TRANSFERENCIA` | No | Manual del vendedor |

### Estados de pago

| `payments.estado` | Significado |
|---|---|
| `PENDIENTE` | Iniciado, sin confirmar |
| `PENDIENTE_VERIFICACION` | Pago móvil/transferencia esperando revisión del seller |
| `APROBADO` | Confirmado |
| `RECHAZADO` | Fallido |
| `REEMBOLSADO` | Revertido |
| `ANULADO` | Cancelado |

## Alternativas consideradas

### Solo pago con Yape/Plin, verificado por captura de pantalla

| A favor | En contra |
|---|---|
| Sin pasarela, sin costos | Verificación 100% manual: el vendedor debe revisar cada uno |
| Simple de implementar | El cliente ve un mensaje de "esperando confirmación" y se va |
| | No escala con el volumen |
| | El dinero puede estar en la cuenta y el pedido nunca marcarse |

**Descartado como vía única**, pero **mantenido** como complementario, porque es la forma en que realmente compra una parte importante de los clientes.

### Solo tarjeta (integración con pasarela)

Descartado. El negocio perdería ventas: en Chiclayo, el pago por Yape es la norma para compras informales. Obligar a tener tarjeta es una barrera directa.

### Pagos con QR interoperable (Yape QR dinámico desde la API)

**Descartado para la v1.** La API de Yape para générer QR dinámico requiere acuerdo comercial con el proveedor, y para pagos mayores a un umbral tiene condiciones distintas a las de QR de cobro estático. Se evaluará en v2.

### Verificación automática de Yape por API

Descartado: no existe API pública de consulta de movimientos de Yape/Plin para comercios sin acuerdo empresarial. Solo el administrador de la cuenta ve los movimientos en la app.

### Implementar la verificación por OCR de la captura

Descartado para la v1: añade complejidad de visión artificial para automatizar un proceso que un humano hace en 30 segundos. **Es candidato natural a una mejora futura** si el volumen de pedidos lo justifica.

## Consecuencias

**Positivas**
- Se cubren los dos métodos que los clientes realmente usan.
- El flujo manual deja **trazabilidad**: quién verificó, cuándo y con qué evidencia.
- La implementación de la v1 no depende de contratar pasarela: se puede entregar el proyecto completo con la pasarela de prueba (ADR-007).

**Negativas / costos**
- **Dos flujos que mantener y dos conjuntos de estados.** Más código y más superficie de prueba.
- El pago manual introduce **tiempo de espera**: el pedido no se procesa hasta que el vendedor actúe. Requiere que el panel notifique al vendedor (`notifica_vendedor = 1` en el estado `PAGO_POR_VERIFICAR`) y que exista un SLA recordatorio (job `sp_pedidos_pendientes_vencimiento`).
- La pasarela chosen deve soportar tokenización y webhooks con firma. Esa restricción reduce el número de pasarelas compatibles (decisión pendiente: Culqi vs Izipay vs Mercado Pago).

**Impacto en el proyecto**
- `payments.metodo_pago` con `CHECK` sobre los cuatro valores de la tabla de arriba.
- `payments.estado` enums los seis estados listados.
- La **evidencia** del pago manual: `payments.evidencia_url` (imagen subida a `storage/`) y `payments.verificado_por` / `verificado_en`.
- El panel admin muestra una **cola de verificación** como sección propia, no dentro de la lista de pedidos: es la tarea diaria principal del vendedor.
- La tabla `settings` guarda los datos de cuenta para Yape/Plin/transferencia (número, titular, banco), que se muestran al cliente al elegir ese método.

**Pendiente de decisión:** pasarela de tarjetas concreta → Fase 7. Criterio: tokenización en el navegador, webhooks firmados, costo por transacción compatible con el ticket promedio del negocio, y prueba en sandbox.
