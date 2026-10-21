# ADR-010 — Checkout como invitado y consulta de pedido por código

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Dominio / Seguridad

---

## Contexto

El negocio vende miel a consumers finales (personas naturales en Chiclayo) y por redes sociales. Pedirle a un cliente que se registre **antes** de comprar es una barrera de conversión alta, y el negocio no necesita los datos del cliente para despachar: la venta presencial y los envíos locales funcionan con nombre, teléfono, dirección y el código del pedido.

Al mismo tiempo, el cliente necesita una forma de **consultar el estado de su pedido** sin una cuenta.

## Decisión

### 1. Checkout como invitado

El pedido se puede crear **sin cuenta**. Los campos mínimos del cliente se piden durante el checkout.

| Campo | ¿Obligatorio? | Nota |
|---|---|---|
| `nombre_completo` | Sí | |
| `telefono` | Sí | Formato peruano, con validación |
| `email` | No | Si se omite, la consulta de estado es solo por código |
| `tipo_documento` | No | `DNI` / `CE` — para factura |
| `numero_documento` | No | Validado contra RENIEC si se proporciona |
| `direccion` | Sí, solo con envío | |
| `referencia_direccion` | No | "Casa frente al parque", "tercer piso" |
| `distrito` | Condicional | Requerido si hay envío |

### 2. Código de pedido

Formato: **`NAN-AAAA-NNNNNN`**

| Parte | Significado |
|---|---|
| `NAN` | Prefijo fijo del negocio |
| `AAAA` | Año (4 dígitos) |
| `NNNNNN` | Secuencial de 6 dígitos por año |

Ejemplos: `NAN-2026-000001`, `NAN-2026-000002`.

**Propiedades:**
- Generado por la base de datos (secuencia por año), **nunca** por el cliente.
- **Único** dentro del año.
- No revela información del cliente: el código es un identificador opaco.
- Formato corto y dictable por teléfono. El cliente puede leerlo por WhatsApp.

### 3. Consulta de estado sin cuenta

```
GET /api/v1/orders/track/:codigo
```

Devuelve estado, resumen de los artículos y el timeline de estados. **Sin datos personales del cliente** más allá del nombre y el teléfono, que el propio cliente ya proporcionó.

**Protección contra enumeración:** el código tiene 6 dígitos secuenciales, lo que lo hace adivinable. Por eso:

| Medida | Detalle |
|---|---|
| Rate limit estricto | 10 consultas/minuto por IP en esta ruta |
| Código de pedido en el correo | El cliente recibe el código por correo y puede confirmarlo |
| Confirmación de recepción | `POST /orders/:codigo/confirm-received` requiere el código + una **clave de confirmación** (token) enviada al cliente |
| Sin datos sensibles | La respuesta no expone email completo, dirección ni documentos |

### 4. La columna `email` y el modelo de "cliente sin cuenta"

Cuando el cliente no deja email, no hay cuenta. La tabla `orders` guarda los datos de contacto **directamente**, sin una tabla `customers` asociada.

> **Pendiente de confirmación del solicitante:** si el negocio quiere que "un cliente con el mismo teléfono acumula historial y recibe ofertas", hará falta una tabla `customers` separada en la v1 o en la v2. En la v1 se asume **cliente sin historial**.

## Alternativas consideradas

### Registro obligatorio antes de comprar

Descartado. Barrera de conversión alta, y el negocio no lo necesita. El requisito es explícito: *"el cliente no necesita registrarse para comprar; compra como invitado y consulta su pedido con un código"*.

### Pedido por número secuencial corto (ej. `0001`)

Descartado: adivinable desde el primer pedido. El prefijo `NAN-AAAA-` no añade entropía real, pero estandariza el formato, evita colisiones con otros sistemas y hace el código autodescriptivo.

### UUID como identificador de pedido

| A favor | En contra |
|---|---|
| No adivinable | Imposible de dictar por teléfono |
| Entropía real | El cliente no puede recordarlo |
| | No refleja el orden temporal |

**Descartado** como identificador de cara al cliente. **Se conserva** el UUID como clave primaria interna (`orders.id`), por lo que el código es **únicamente** para el usuario. Lo ideal es tener ambos: el interno para integridad y el legible para el usuario.

### Email + contraseña obligatorios

Descartado por la misma razón que el registro: fricción innecesaria para un producto de bajo costo.

### WhatsApp como canal de consulta

Descartado como mecanismo principal (requiere un bot, un número de WhatsApp Business y un contrato), pero **se mantiene como complementario**: los avisos por correo incluyen el código, y el seller puede responder por WhatsApp. Decisión de negocio, no técnica.

## Consecuencias

**Positivas**
- Conversión inmediata: nadie tiene que crear una cuenta para comprar.
- El negocio puede atender la consulta por cualquier medio, sin depender de que el cliente use un canal específico.
- Menos datos personales almacenados → menor superficie bajo la Ley 29733.
- El código es legible y dictable: reduce el soporte por teléfono.

**Negativas / costos**
- **Sin historial del cliente** en la v1: no se puede_segmentar ni saber si un cliente es recurrente.
- El rate limit de `/orders/track` puede afectar a un cliente legítimo que consulta varias veces en pocos minutos. Se usa un límite generoso (10/min) y se documenta.
- La superficie de enumeración existe y depende de la disciplina del rate limit.
- El correo es el canal de confianza: si el cliente no deja email, su única prueba de compra es el código. La entrega en mostrador cubre ese caso.

**Impacto en el proyecto**
- `sp_crear_pedido` genera el código con la secuencia por año (`seq_order_code_YYYY`).
- `POST /orders` acepta `Idempotency-Key` para que un doble clic no cree dos pedidos.
- La ruta `/orders/track/:codigo` tiene su propio limitador, más estricto que el global.
