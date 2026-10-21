# ADR-006 — Máquina de estados por datos (catálogo + transiciones con efectos)

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Dominio / Base de datos

---

## Contexto

El pedido tiene un ciclo de vida de 11 estados. El requisito es explícito: *"la máquina de estados debe diseñarse de manera que posteriormente podamos agregar o modificar estados sin romper la arquitectura"*. La revisiónarlojaanó además que el catálogo de estados **no** se administre desde el panel en la v1, sino **solo por datos/migración**.

## Decisión

La máquina de estados vive **íntegramente en la base de datos**, en tres tablas:

### 1. `order_status` — el catálogo de estados

| Columna | Función |
|---|---|
| `codigo` | Identificador estable (`PENDIENTE_PAGO`, `APROBADO`…) |
| `nombre`, `descripcion` | Presentación |
| `consume_stock` | Efecto: al entrar a este estado, consume stock definitivo |
| `libera_stock` | Efecto: al entrar a este estado, libera la reserva |
| `exige_motivo` | La transición a este estado exige un motivo |
| `notifica_cliente`, `notifica_vendedor` | Efecto: dispara notificación |
| `es_final` | Estado terminal |
| `orden` | Orden de presentación en la UI |
| `activo` | Permite desactivarlo sin borrarlo |

### 2. `order_status_transition` — el grafo

| Columna | Función |
|---|---|
| `estado_origen_id` | Nodo origen |
| `estado_destino_id` | Nodo destino |
| `requiere_usuario` | Solo un usuario autenticado (vendedor) puede ejecutar la transición |
| `activo` | Permite desactivar una arista |

`UNIQUE(estado_origen_id, estado_destino_id)`.

### 3. `order_status_history` — el registro inmutable

Cada cambio de estado inserta una fila con `estado_anterior_id`, `estado_nuevo_id`, `usuario_id` (nullable para eventos del sistema), `motivo`, `ip`, `user_agent` y `fecha_cambio`. **Solo INSERT. Nunca UPDATE ni DELETE.**

### El motor

El servicio de pedidos ejecuta una transición así:

```text
1. Leer la transición (origen, destino) en order_status_transition
   → si no existe o está inactiva → 409 TRANSICION_NO_PERMITIDA
2. Verificar que la transición actual del pedido == origen
   → si no → 409 (con la lista de transiciones válidas)
3. Si el destino exige motivo y no llega → 400 MOTIVO_OBLIGATORIO
4. Si el destino requiere usuario y no hay sesión → 401
5. En una TRANSACCIÓN:
     a. Aplicar los efectos del destino (consume_stock / libera_stock)
     b. Actualizar orders.estado_id
     c. INSERT en order_status_history
     d. COMMIT
```

**El servicio no contiene una lista de estados.** Ni un `switch`, ni un `if` por nombre de estado, ni un enum en JavaScript. Solo lee tablas.

## Alternativas consideradas

### Enums de JavaScript

```js
const ESTADOS = ['PENDIENTE_PAGO', 'PAGADO', /* ... */];
```

| A favor | En contra |
|---|---|
| Tipado, autocompletado, rápido | **Agregar un estado = cambiar código + deploy** |
| No se puede escribir un estado inválido | No se puede consultar ni administered desde el panel |
| | Los efectos (consumir/liberar stock) quedarían en un `switch` → la lógica se fragmenta |

**Descartado**: contradice directamente el requisito de extensibilidad.

### Columna `estado VARCHAR` en `orders` + validación en JavaScript

Descartado por el mismo motivo, y sin el beneficio del tipado.

### Tabla de estados **con** editor en el panel administrativo

Considerado y **descartado por decisión del solicitante** (Fase 1, revisión del 21/10/2026).

| A favor | En contra |
|---|---|
| El vendedor podría crear "EN CUSTODIA" sin programador | Un grafo de estados mal editado deja pedidos en estados inconsistentes |
| Cumple la extensibilidad de forma literal | Superficie de error considerable (validación de ciclos, de estados huérfanos, de nodos finales) |
| | Es funcionalidad de **administración de la aplicación**, no del negocio: el vendedor de miel no necesita crear estados |

**Consecuencia:** agregar un estado requiere una migración de datos. Es deliberado: una migración es revisable, versionada y reversible. Un clic en un panel no lo es.

### Tabla de estados sin columna de efectos (solo transiciones válidas)

Descartado. Con solo transiciones válidas, el servicio necesita saber **qué hacer** en cada transición, y eso se codificaría con `if`. Volveríamos al problema original. Los efectos declarados en la tabla son lo que mantiene la lógica en los datos.

## Consecuencias

**Positivas**
- **Agregar un estado = `INSERT` en dos tablas + una migración.** Cero cambios de código, cero deploy de aplicación.
- **Cambiar un efecto** (por ejemplo, mover el consumo de stock de `APROBADO` a `PAGADO`) = un `UPDATE` en una fila.
- El historial es evidencia de auditoría sólida: quién, cuándo, desde qué estado, a qué estado, por qué.
- Los efectos de stock y las notificaciones se ejecutan de forma **uniforme**, sin importar quién ejecuta la transición (vendedor, cliente o job).
- La UI puede renderizar el grafo leyendo las tablas, sin código de estados.

**Negativas / costos**
- Un `SELECT` extra por transición (consultar la arista y el destino). Se mitiga con **una sola consulta** que trae origen, destino y ambos conjuntos de banderas.
- Requiere disciplina de diseño: las tablas son el contrato, y hay que mantenerlas coherentes con la documentación (`03-reglas-de-negocio.md`).
- Sin validación en el panel, un error en la migración podría crear una transición imposible. Se mitiga con una prueba de integridad que verifica que todo estado es alcanzable desde `PENDIENTE_PAGO` y que todo estado no-final tiene al menos una salida.

**Impacto en el proyecto**
- `db/seed.sql` carga los 11 estados y ~14 transiciones iniciales.
- `sp_cambiar_estado_pedido` encapsula la validación y los efectos.
- `services/orderState.service.js` orquesta: valida, delega al SP, dispara notificaciones.
- `docs/03-reglas-de-negocio.md` §4 es la especificación legible de las mismas tablas.
