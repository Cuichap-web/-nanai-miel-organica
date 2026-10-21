# 03 — Reglas de Negocio

**Proyecto:** NANAI Miel Orgánica  
**Versión:** 1.0 (Fase 1 — Especificación)  
**Estado:** En revisión  
**Relación:** Hereda de `01-requisitos.md` y `02-actores-y-casos-de-uso.md`

---

## 1. Objetivo

Este documento fija las **reglas inquebrantables** del dominio. 

- Las transiciones de estados **no** son `if/else` dispersos: son datos.
- El stock se rige por **dos libros** (físico y reservas), nunca por una sola columna.
- El descuento definitivo del stock **se liga a una regla**, no a una acción arbitraria del vendedor.
- Todo cambio queda trazado con fecha, usuario, motivo y origen.

---

## 2. Modelo de stock

El sistema distingue tres conceptos que **nunca** deben mezclarse.

### 2.1 Conceptos

| Concepto | Definición | ¿Se descuenta? |
|---|---|---|
| **Stock físico** | Unidades realmente existentes en almacén. Es la verdad del inventario. | Solo al **consumir** la venta. |
| **Stock reservado** | Unidades bloqueadas por un pedido con reserva vigente (`PENDIENTE_PAGO`). Aún no han salido del almacén. | No. Se "mueven" entre libros. |
| **Stock disponible** | Unidades que pueden agregarse al carrito/checkout en este momento. | `disponible = stock_fisico - stock_reservado_vigente` |

> **Regla:** El carrito **nunca** lee ni modifica `stock_reservado`. Únicamente consulta `disponible`. La reserva solo nace al **crear el pedido** (CU-06), cubriendo **exactamente el proceso de pago**.

### 2.2 Operaciones sobre el stock

| Operación | Cuándo | Efecto | Movimiento |
|---|---|---|---|
| **RESERVAR** | Al crear el pedido (CU-06). Dentro de transacción con `SELECT ... FOR UPDATE`. | `stock_reservado += cantidad`. `stock_fisico` **sin cambios**. | `tipo = RESERVA`, `origen = VENTA_ONLINE` |
| **CONSUMIR** | Al entrar en un estado con `consume_stock = 1`. Para la v1: **al pasar a `APROBADO`**. | `stock_fisico -= cantidad`. `stock_reservado -= cantidad`. | `tipo = VENTA`, `origen = VENTA_ONLINE` o `VENTA_PRESENCIAL` |
| **LIBERAR** | Al expirar reserva (CU-34), al desaprobar (CU-23) o al cancelar con motivo válido. | `stock_reservado -= cantidad`. `stock_fisico` **sin cambios**. | `tipo = LIBERACION`, con motivo |
| **INGRESAR** | Registro de ingreso desde el panel (CU-17). | `stock_fisico += cantidad`. | `tipo = INGRESO`, `usuario_id`, `motivo` |
| **AJUSTE/MERMA** | Ajuste manual o merma justificada (CU-18). | `stock_fisico +=/-= cantidad`. | `tipo = AJUSTE` o `MERMA`, **justificación obligatoria** |

> **Crítico:** Todo cambio de stock **obligatoriamente** genera un registro en `inventory_movements` dentro de la **misma transacción** que lo produjo. Nunca se actualiza stock sin movimiento.

---

## 3. Reserva temporal

| Regla | Valor/Detalle |
|---|---|
| **Momento de creación** | Al crear el pedido (CU-06). **No** en el carrito. |
| **Propósito** | Cubrir **únicamente el proceso de pago** para evitar sobreventa entre clientes concurrentes. |
| **TTL por defecto** | **30 minutos**. Configurable desde el panel (`settings.reserva_ttl_minutos`). |
| **Cálculo** | `reserva_expira_en = NOW() + INTERVAL reserva_ttl_minutos MINUTE` |
| **Afecta disponibilidad** | Sí. `disponible = fisico - reservado_vigente`. |
| **Expiración** | Ejecutada por el job `jobs/expirar-reservas.js` (CU-34). |
| **Protección contra carrera** | El job utiliza `SELECT ... FOR UPDATE SKIP LOCKED` / bloqueo por fila para evitar que dos instancias procesen el mismo pedido. |
| **Pago a tiempo** | Si el pago se confirma **antes** de la expiración, la reserva **permanece** hasta que se ejecute el `CONSUMIR` al pasar a `APROBADO`. No se libera por haber pagado. |

---

## 4. Máquina de estados

### 4.1 Principios

- **Basada en datos.** Los estados y transiciones viven en `order_status` y `order_status_transition`. 
- **Sin editor en v1.** Se gestionan **únicamente por migración/seed**. Esto satisface *"agregar o modificar estados sin romper la arquitectura"* sin añadir una superficie compleja al panel.
- **Efectos declarados.** Cada transición puede llevar `efecto_consume_stock`, `efecto_libera_stock`, `exige_motivo`, `notifica_cliente`, `notifica_vendedor`, `es_final`.
- **Historial obligatorio.** Todo cambio inserta en `order_status_history` con `estado_anterior_id`, `estado_nuevo_id`, `usuario_id` (nullable para eventos del sistema), `motivo`, `ip`, `user_agent`, `fecha_cambio`.
- **Transiciones válidas.** El servicio valida contra la tabla. Si no existe la transición permitida, se rechaza con `409` y se muestra el listado de transiciones válidas para ese estado.

### 4.2 Catálogo de estados (v1)

Estos son los estados base para cubrir el flujo definido. Pueden añadirse nuevos por migración sin modificar lógica.

| Código | Nombre | Descripción | `consume_stock` | `libera_stock` | `es_final` | Notas |
|---|---|---|---|---|---|---|
| `PENDIENTE_PAGO` | Pendiente de pago | Pedido creado con reserva vigente. Esperando pago. | `0` | `0` | `0` | Estado inicial para pedidos online. |
| `PAGO_POR_VERIFICAR` | Pago por verificar | Cliente indicó pago por Yape/Plin/transferencia. Pendiente de validación por el vendedor. | `0` | `0` | `0` | Stock sigue reservado. |
| `PAGADO` | Pagado | Pago con tarjeta confirmado por webhook + verificación contra pasarela, o pago manual verificado. | `0` | `0` | `0` | Stock **sigue reservado**. Aún no se consume stock definitivo. |
| `PENDIENTE_APROBACION` | Pendiente de aprobación | Listo para revisión del vendedor. | `0` | `0` | `0` | Transición automática o explícita según configuración. |
| `APROBADO` | Aprobado | **Venta procesada.** Aquí se **consume el stock definitivo**. | `1` | `0` | `0` | **Punto de descuento definitivo para la v1.** Genera movimiento `VENTA`. |
| `DESAPROBADO` | Desaprobado | Pedido rechazado por el vendedor. | `0` | `1` | `1` | **Motivo obligatorio.** Libera la reserva. Notifica al cliente con el motivo. |
| `EN_PREPARACION` | En preparación | El pedido está siendo empacado. | `0` | `0` | `0` | Solo accesible desde `APROBADO`. |
| `ENVIADO` | Enviado | Entregado a la agencia de transporte. | `0` | `0` | `0` | Requiere agencia/código de seguimiento cuando aplique. |
| `EN_TRANSITO` | En tránsito | En camino al cliente. | `0` | `0` | `0` | Puede actualizarse con enlace de seguimiento. |
| `RECIBIDO` | Recibido | Cliente confirmó recepción o vendedor lo marcó según corresponda. | `0` | `0` | `0` | Puede generar notificación. |
| `COMPLETADO` | Completado | Proceso finalizado correctamente. | `0` | `0` | `1` | Estado final. |
| `CANCELADO` | Cancelado | Cancelado por reserva expirada, por cliente o por regla. | `0` | `1` | `1` | Si hay reserva vigente, se libera. Si ya se consumió stock (improbable con este flujo), se evalúa caso a caso con auditoría. |

### 4.3 Grafo de transiciones (v1)

| Desde | Hacia | Quién | Efectos | Condiciones |
|---|---|---|---|---|
| `PENDIENTE_PAGO` | `PAGO_POR_VERIFICAR` | Cliente | `libera_stock=0`, `consume_stock=0`, notifica vendedor | Cliente registró pago manual. |
| `PENDIENTE_PAGO` | `PAGADO` | Sistema (webhook + verificación) | `0/0`, registra pago | Pago con tarjeta aprobado y verificado contra la pasarela. Idempotente. |
| `PENDIENTE_PAGO` | `CANCELADO` | Sistema (job) | `libera_stock=1`, `consume_stock=0`, registra motivo `RESERVA_EXPIRADA` | Reserva vencida. Verifica que no exista pago confirmado antes de cancelar. |
| `PAGO_POR_VERIFICAR` | `PAGADO` | Vendedor | `0/0`, registra pago con `usuario_id` y referencia | Pago verificado manualmente. |
| `PAGO_POR_VERIFICAR` | `PENDIENTE_PAGO` | Vendedor | `0/0` | Pago rechazado. Reserva sigue vigente si no expiró. |
| `PAGADO` | `PENDIENTE_APROBACION` | Sistema/Vendedor | `0/0` | Listo para aprobación. |
| `PENDIENTE_APROBACION` | `APROBADO` | Vendedor | **`consume_stock=1`, `libera_stock=0`**, genera movimiento `VENTA`, registra historial | **Punto de consumo definitivo.** Requiere que el pago esté `APROBADO`. |
| `PENDIENTE_APROBACION` | `DESAPROBADO` | Vendedor | `consume_stock=0`, **`libera_stock=1`**, **`exige_motivo=1`**, notifica cliente | Motivo obligatorio. Reserva liberada. |
| `APROBADO` | `EN_PREPARACION` | Vendedor | `0/0` | El stock ya fue consumido en la transición a `APROBADO`. |
| `EN_PREPARACION` | `ENVIADO` | Vendedor | `0/0` | Recomendado registrar agencia + código + fecha. |
| `ENVIADO` | `EN_TRANSITO` | Vendedor/Sistema | `0/0` | Opcional. |
| `EN_TRANSITO` | `RECIBIDO` | Vendedor/Cliente | `0/0` | Cliente puede confirmar desde "Rastrear mi pedido". |
| `RECIBIDO` | `COMPLETADO` | Vendedor/Sistema | `0/0`, `es_final=1` | Cierre del ciclo. |
| `PENDIENTE_PAGO` | `CANCELADO` | Vendedor/Sistema | `libera_stock=1`, motivo registrado | Solo si aplica por regla/configuración. |

> **Nota:** La venta presencial **NO** utiliza esta máquina de estados. Es una operación atómica de caja (CU-27): se crea la venta, se **consume stock definitivo** en esa misma transacción y se genera la boleta interna.

---

## 5. Reglas detalladas por caso

### 5.1 Creación del pedido (CU-06)

1. **Validación previa:** Carrito válido, productos activos, precios vigentes tomados desde BD.
2. **Disponibilidad:** `disponible >= cantidad` para cada ítem.
3. **Transacción obligatoria:** `BEGIN` → generar `NAN-AAAA-NNNNNN` con contador bloqueado (`SELECT ... FOR UPDATE`) → reservar stock → insertar pedido + detalle con **snapshot** → insertar historial → `COMMIT`. Si falla cualquier paso → `ROLLBACK`.
4. **Reserva:** Se registra en `order_reservations` con `pedido_id`, `producto_id`, `cantidad`, `reserva_expira_en`, `estado = VIGENTE`.
5. **Idempotencia:** Si llega `idempotency_key`, se busca un pedido con esa clave. Si existe y es válido, se devuelve el mismo pedido sin duplicar reservas.

### 5.2 Pago con tarjeta (CU-07)

1. **Intención de pago:** Generada con importe exacto del pedido (calculado en servidor).
2. **Datos sensibles fuera:** Tarjeta/CVV nunca pasan por nuestro backend.
3. **Webhook:** Solo se acepta con **firma válida**. Se guarda `provider_event_id` con `UNIQUE` para prevenir duplicados.
4. **Verificación cruzada:** Antes de transicionar a `PAGADO`, se consulta el **estado real** del pago a la pasarela. Solo si ambas fuentes coinciden se confirma.
5. **Stock:** Permanece **reservado**. **No** se consume en este punto.

### 5.3 Pago manual (CU-08, CU-26)

1. **Cliente:** Elige Yape/Plin/Transferencia, ve datos de cuenta y código de referencia.
2. **Estado:** Pasa a `PAGO_POR_VERIFICAR`.
3. **Verificación:** Únicamente el **vendedor autenticado** puede pasar a `PAGADO`. Se registra `verificado_por`, `fecha_verificacion`, `referencia_pago`.
4. **Rechazo:** Si no se encuentra el pago, vuelve a `PENDIENTE_PAGO` **mientras la reserva siga vigente**.

### 5.4 Aprobación y consumo de stock (CU-22)

1. **Precondición estricta:** El pedido debe estar en `PENDIENTE_APROBACION` y tener pago `APROBADO` (o validado según regla).
2. **Transición:** `PENDIENTE_APROBACION → APROBADO`
3. **Efecto automático:** Al detectar `consume_stock = 1`, el servicio ejecuta:
   - Por cada línea: validar que haya reserva suficiente
   - `stock_fisico -= cantidad`
   - `stock_reservado -= cantidad`
   - Insertar en `inventory_movements` (`tipo = VENTA`, `origen`, `pedido_id`, `usuario_id`)
   - Marcar reserva como `CONSUMIDA`
4. **Historial:** Se registra con `usuario_id` del vendedor que aprobó.
5. **Notificación:** Se envía al cliente.

### 5.5 Desaprobación y liberación (CU-23)

1. **Motivo obligatorio:** Si `exige_motivo = 1`, el backend rechaza la petición sin motivo.
2. **Liberación:** Si `libera_stock = 1`, se libera la reserva completa. `stock_reservado -= cantidad`. Movimiento `LIBERACION` con motivo.
3. **Visibilidad:** El motivo se guarda en `order_status_history.motivo` y **se muestra** al cliente al consultar por código.

### 5.6 Expiración de reservas (CU-34)

1. **Búsqueda:** Pedidos en `PENDIENTE_PAGO` con `reserva_expira_en <= NOW()` y reserva `VIGENTE`.
2. **Seguridad:** Antes de cancelar, se verifica si existe un pago **aprobado/confirmado**. Si existe, **NO** se cancela.
3. **Procesamiento por lote:** Con bloqueo por fila para evitar doble procesamiento.
4. **Acción:** Transicionar a `CANCELADO` con motivo `RESERVA_EXPIRADA`, liberar reservas, generar movimientos y notificar.
5. **Idempotencia:** Si ya fue procesado, el job lo omite.

### 5.7 Venta presencial (CU-27)

1. **Atómico:** Todo en una transacción.
2. **Sin reserva:** No se crea reserva temporal. Se valida `disponible` directamente.
3. **Consumo inmediato:** Se **consume stock definitivo** al confirmar.
4. **Sin máquina de estados:** Genera `venta_presencial` con sus líneas y boleta interna.
5. **Compartido:** Usa el **mismo** motor de totales, el **mismo** inventario y el **mismo** catálogo de productos.

---

## 6. Reglas para el modelo de datos

Para que esto sea ejecutable en MySQL 8, el esquema debe reflejarlo.

| Tabla | Propósito | Notas |
|---|---|---|
| `order_status` | Catálogo de estados | Clave por `codigo` único. Campos: `consume_stock` (TINYINT(1)), `libera_stock` (TINYINT(1)), `exige_motivo` (TINYINT(1)), `notifica_cliente` (TINYINT(1)), `notifica_vendedor` (TINYINT(1)), `es_final` (TINYINT(1)), `orden` (INT). **Solo se modifica por migración.** |
| `order_status_transition` | Grafo permitido | `estado_origen_id`, `estado_destino_id`, efectos, `requiere_usuario` (TINYINT(1)), `activo` (TINYINT(1)). `UNIQUE(estado_origen_id, estado_destino_id)`. |
| `orders` | Cabecera de pedido | `codigo` UNIQUE `NAN-YYYY-NNNNNN`. `tipo_venta` ENUM('ONLINE','PRESENCIAL'). `estado_id`. `total`, `subtotal`, `costo_envio`, `igv_incluido` (TINYINT(1)) DEFAULT 1. `reserva_expira_en`. |
| `order_items` | Detalle | **Snapshot obligatorio:** `precio_unitario`, `cantidad`, `subtotal_linea`. Nunca se lee el precio actual para recalcular pedidos históricos. |
| `order_status_history` | Auditoría inmutable | Sin `UPDATE`/`DELETE`. Guarda `usuario_id` nullable, `motivo`, `metadata` JSON opcional. |
| `order_reservations` | Reservas vigentes | `pedido_id`, `producto_id`, `cantidad`, `reserva_expira_en`, `estado` ENUM('VIGENTE','CONSUMIDA','LIBERADA','EXPIRADA'). Índice `(estado, reserva_expira_en)`. |
| `products` | Producto | `stock_fisico` (INT UNSIGNED), `precio` DECIMAL(10,2), `activo` (TINYINT(1)). **No** guardar `stock_disponible` calculado. |
| `inventory_movements` | Movimientos auditables | `producto_id`, `tipo` ENUM('INGRESO','VENTA','AJUSTE','MERMA','LIBERACION','RESERVA'), `cantidad` (INT, con signo o absoluto según convención), `stock_fisico_antes`, `stock_fisico_despues`, `stock_reservado_antes`, `stock_reservado_despues`, `origen`, `pedido_id`, `venta_presencial_id`, `usuario_id`, `motivo`, `fecha`. |
| `payments` | Pagos | Relación con pedido, `proveedor`, `estado`, `monto`, `moneda` CHAR(3)='PEN', `referencia_externa`, `provider_event_id` **UNIQUE**, `verificado_por`, `fecha_verificacion`. |

**Reglas de integridad:**

- `DECIMAL(10,2)` para todos los importes. **Prohibido** `FLOAT/DOUBLE`.
- `utf8mb4_unicode_ci` para textos.
- Claves foráneas con `RESTRICT` salvo casos de dependencia fuerte justificada.
- **Nunca** actualizar `order_status_history`. Solo `INSERT`.
- **Nunca** recalcular totales históricos desde `products`.

---

## 7. Concurrencia, idempotencia y seguridad

| Aspecto | Regla | Implementación |
|---|---|---|
| **Sobreventa** | Cero tolerancia | `SELECT stock_fisico, ... FROM products WHERE id = ? FOR UPDATE` + validar contra reservas vigentes. Todo dentro de transacción. |
| **Reserva simultánea** | Solo una gana | Bloqueo por producto. Si no hay suficiente, `ROLLBACK` con error claro. |
| **Job de expiración** | Sin doble procesamiento | `SELECT ... FROM orders WHERE estado = PENDIENTE_PAGO AND reserva_expira_en <= NOW() FOR UPDATE SKIP LOCKED` por lote. |
| **Webhooks duplicados** | Idempotente | `provider_event_id` con `UNIQUE`. Si ya existe, responder 200 sin reprocesar. |
| **Clave de idempotencia** | Crear pedido idempotente | `Idempotency-Key` en header o `idempotency_key` en cuerpo. Buscar por clave antes de crear. |
| **Consulta por código** | Sin enumeración | Rate limiting + respuesta genérica para código inexistente. No filtrar por cliente. |
| **Autenticación panel** | Sesión segura | `httpOnly`, `SameSite=Lax`, `Secure` en prod, expiración por inactividad. |
| **Contraseñas** | Argon2id | `@node-rs/argon2` con parámetros razonables. Nunca texto plano. |

---

## 8. Checklist de validación

Antes de dar por correcta cualquier implementación, debe cumplirse:

- [ ] El carrito **no** crea ni modifica reservas.
- [ ] Al crear pedido, la reserva cubre el pago y tiene TTL configurado.
- [ ] El descuento definitivo **solo** ocurre al pasar a `APROBADO` con `consume_stock = 1`.
- [ ] `DESAPROBADO` libera la reserva sin haber consumido stock.
- [ ] Expirar reserva cancela el pedido y libera stock, salvo que exista pago confirmado.
- [ ] Todo cambio de stock tiene su movimiento en la misma transacción.
- [ ] Todo cambio de estado queda en `order_status_history` (inmutable).
- [ ] Transición inválida → `409` con transiciones permitidas.
- [ ] Venta presencial consume stock inmediato, fuera de la máquina de estados.
- [ ] Agregar un nuevo estado = `INSERT` en tablas + migración. **Sin cambios de lógica**.
- [ ] Precios en `DECIMAL(10,2)`, `disponible` calculado, nunca almacenado.

---

## 9. Glosario rápido

| Término | Significado |
|---|---|
| **Consumir stock** | Restar del `stock_fisico` (venta procesada). |
| **Reservar stock** | Bloquear unidades para el pago sin sacarlas del almacén. |
| **Liberar reserva** | Devolver unidades reservadas a `disponible`. |
| **Venta procesada** | En la v1 = pedido en `APROBADO`. |
| **Snapshot** | Copia inmutable del precio/cantidad en `order_items`. |
| **Efecto declarativo** | La acción (consumir/liberar) la decide el estado, no el controlador. |
