# ADR-005 — Stock por regla: dos libros y punto único de consumo

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Dominio / Base de datos

---

## Contexto

El negocio necesita evitar la sobreventa sin dejar mercancía bloqueada, distinguir la **reserva** de la **venta definitiva**, y saber en qué momento exacto el stock debe descontarse. La revisión del documento de requisitos fijó que el descuento definitivo no debe depender de una acción arbitraria del vendedor, sino de una **regla de negocio**.

## Decisión

### 1. Dos libros de stock

| Libro | Campo | Significado |
|---|---|---|
| **Físico** | `products.stock_fisico` | Unidades realmente en almacén |
| **Reservado** | `order_reservations` (filas `VIGENTE`) | Unidades bloqueadas por pedidos sin pagar |
| **Disponible** | *Calculado* | `stock_fisico - reservas_vigentes` |

El stock disponible **nunca** se almacena: es una vista que se calcula. Almacenarlo crea una tercera copia que se desincroniza.

### 2. Operaciones y su journaling

| Operación | Libro físico | Libro de reservas | Movimiento |
|---|---|---|---|
| `RESERVAR` | no cambia | +cantidad | `RESERVA` |
| `CONSUMIR` | −cantidad | −cantidad | `VENTA` |
| `LIBERAR` | no cambia | −cantidad | `LIBERACION` |
| `INGRESAR` | +cantidad | no cambia | `INGRESO` |
| `AJUSTE` / `MERMA` | ±cantidad | no cambia | `AJUSTE` / `MERMA` |

Toda operación genera una fila en `inventory_movements` **en la misma transacción**, con los valores antes y después de ambos libros.

### 3. El punto de consumo

**El stock definitivo se consume al entrar en el estado `APROBADO`.**

El estado lleva una bandera `consume_stock = 1`. El servicio de pedidos, al ejecutar una transición, lee esa bandera del catálogo de estados y aplica el efecto. **La lógica no dice "si el destino es APROBADO, descuenta"**: dice "si el destino consume stock, descuenta". Cambiar el punto de consumo es un `UPDATE` sobre una fila, no un cambio de código.

```
PENDIENTE_PAGO ──pago──▶ PAGADO ──▶ PENDIENTE_APROBACION ──vendedor──▶ APROBADO ──▶ EN_PREPARACION ──▶ ...
   reserva activa          reserva activa         reserva activa        ★ CONSUME stock
```

**¿Por qué `APROBADO`?**

| Momento | A favor | En contra |
|---|---|---|
| `PAGADO` | El stock refleja la realidad económica desde el primer momento; los reportes de ventas cuadran con los pagos | Si luego se desaprueba, hay que **reembolsar y reponer** stock. En la v1 el reembolso es manual |
| **`APROBADO`** ← elegido | El vendedor confirma que el pedido es real. Desde ahí, la venta está comprometida. **No hay reembolso en el camino normal** | Hay una ventana (PAGADO→APROBADO) donde el stock está reservado pero no consumido. **Esa ventana está protegida por la reserva**, así que no hay sobreventa |
| `EN_PREPARACION` | Se descuenta al empacar | Demasiado tarde: el stock ya se había prometido a otro pedido. **Riesgo real de sobreventa** |

**La objeción de la revisión** —"el descuento definitivo debe realizarse cuando la venta sea procesada, no simplemente al aprobar el pedido"— se resolvió separando **la regla** de **la acción**: la regla es *"se consume al entrar en un estado marcado `consume_stock`"*, y la asignación de esa marca a `APROBADO` es un dato. Ningún controlador sabe que "aprobar" consume stock: el servicio lee la bandera.

### 4. Reversibilidad

Un pedido en `APROBADO` que pasa a `DESAPROBADO` o `CANCELADO` **repone** el stock: el Stored Procedure detecta que la reserva ya fue consumida y ejecuta la operación inversa (`stock_fisico + N`, movimiento `AJUSTE` con motivo). No se admiten Transitions que dejen el inventario descuadrado.

## Alternativas consideradas

### Un solo campo `stock` (sin reservas)

Descartado. Es la causa clásica de sobreventa: dos clientes leen `stock = 1` al mismo tiempo y ambos pasan el checkout. Con reservas, la reserva se hace bajo bloqueo de fila (`SELECT ... FOR UPDATE`), y solo uno gana.

### `stock` + `stock_reservado` como columnas en `products`

Considerado. Más rápido de consultar que un `SUM` sobre `order_reservations`. **Descartado** para la v1 por dos motivos: (a) requiere mantener **dos** fuentes de verdad sincronizadas manualmente en cada operación, lo que duplica la superficie de error; (b) el cálculo con `SUM` sobre una tabla indexada es perfectamente aceptable a este volumen. **Se revisa** si el catálogo crece a decenas de miles de productos o el tráfico de checkout se vuelve alto.

### Colocar la lógica de stock en JavaScript en lugar de en el Stored Procedure

Descartado. El bloqueo de fila (`SELECT ... FOR UPDATE`) y la transacción deben ocurrir **en la misma conexión y el mismo contexto** que las escrituras. Repartir la operación entre el motor de BD y Node abre la puerta a estados intermedios donde el stock se movió pero el pedido no, o viceversa. La lógica transaccional vive en el Stored Procedure; JavaScript orquesta y reporta.

### Descartar stock al crear el pedido (sin reservas)

Descartado. El cliente puede abandonar el checkout y dejaría mercancía bloqueada indefinidamente. La reserva con TTL resuelve ese caso.

## Consecuencias

**Positivas**
- Sobreventa imposible: toda reserva y todo consumo se hace bajo bloqueo de fila.
- El movimiento de inventario es la **fuente de verdad** del stock. `products.stock_fisico` es un caché del último movimiento.
- Auditoría completa: se puede reconstruir el stock en cualquier fecha.
- Cambiar el punto de consumo o añadir un estado es una modificación de **datos**.
- La ventana "pago pero no aprobado" no genera sobreventa, porque el stock ya está reservado.

**Negativas / costos**
- Dos tablas que mantener coherentes (`products.stock_fisico` y `order_reservations`).
- El `disponible` es un `SUM` sobre reservas: hay que indexarlo bien (`idx_or_reserva(estado, reserva_expira_en)` y `idx_or_producto(producto_id, estado)`).
- Más complejidad conceptual que un simple `stock--`. **Es el precio de la consistencia**, y es el requisito explícito del negocio.

**Impacto en el proyecto**
- `sp_crear_pedido`: reserva bajo `FOR UPDATE`, devuelve `409 STOCK_INSUFICIENTE` con el detalle del faltante.
- `sp_cambiar_estado_pedido`: aplica los efectos declarados por el estado destino.
- `sp_expirar_reservas`: libera reservas vencidas, con `SKIP LOCKED` para job paralelo.
- `sp_venta_presencial`: consume directo, sin reserva.
- Toda la lógica transaccional de stock vive en `db/procedures/`.
