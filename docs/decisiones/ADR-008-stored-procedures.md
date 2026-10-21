# ADR-008 — Stored Procedures como vía principal de acceso a datos

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Base de datos / Backend

---

## Contexto

El flujo exigido es `… → Modelos → Stored Procedures → MySQL`. Además, el proyecto apunta a una evaluación académica donde el uso de Stored Procedures es parte del temario. La regla de negocio más delicada del sistema (stock, reservas, máquina de estados) necesita atomicidad real.

## Decisión

El acceso a datos de la aplicación se hace **exclusivamente** a través de Stored Procedures. Los modelos (`src/models/`) son funciones que invocan un SP y devuelven el resultado tipado.

### Reglas

1. **Ningún `SELECT`/`INSERT`/`UPDATE`/`DELETE` directo** desde `src/`. Solo `CALL sp_*`.
2. **Todo SP que escriba** es transaccional: usa `START TRANSACTION` / `COMMIT` / `ROLLBACK` y `EXIT HANDLER` que hace `ROLLBACK` + `SIGNAL` en caso de error.
3. **Todo SP de escritura** es **idempotente** cuando la operación lo permite, protegiendo contra reintentos del cliente.
4. Los errores de negocio sesignalizan con `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CODIGO:detalle'`, y el modelo traduce ese código al código HTTP del catálogo de errores.
5. Las lecturas de solo reporte pueden ser **vistas** (`CREATE VIEW`), que también son accessed vía `CALL sp_*` para mantener la regla única.

### Inventario previsto

| SP | Responsabilidad |
|---|---|
| `sp_crear_pedido` | Valida stock, crea pedido y líneas, **reserva** |
| `sp_cambiar_estado_pedido` | Valida transición, aplica efectos (consume/libera stock), registra historial |
| `sp_expirar_reservas` | Libera reservas vencidas (TTL), con `SKIP LOCKED` |
| `sp_confirmar_pago` | Marca pago y avanza el estado del pedido |
| `sp_registrar_pago_manual` | Yape/Plin/transferencia: registra pago **pendiente de verificación** |
| `sp_venta_presencial` | Venta en mostrador: consume stock directo, sin reserva |
| `sp_ajustar_stock` | Ajuste manual de inventario con motivo obligatorio |
| `sp_ingreso_stock` | Ingreso de mercadería |
| `sp_registrar_usuario` / `sp_actualizar_usuario` | Gestión de usuarios y roles |
| `sp_login` | Verificación de credenciales (devuelve hash para `argon2.verify`) |
| `sp_consultar_dni` | Consulta de DNI con caché en tabla |
| `sp_reporte_ventas` | Reportes con agregaciones |
| `sp_pedidos_pendientes_vencimiento` | Pedidos cuyo TTL está por expirar (para recordatorios) |

## Alternativas consideradas

### Consultas SQL desde el ORM/Query builder (Knex, Sequelize, TypeORM)

| A favor | En contra |
|---|---|
| Productividad alta, migraciones gestionadas | La lógica transaccional queda en **JavaScript**, lejos del dato |
| Es portable entre motores | El bloqueo de fila y la transacción se coordinan desde Node: más superficie de error |
| Fácil de testear con mocks | El `SELECT ... FOR UPDATE` funciona, pero el "leer y luego escribir" en JS abre ventanas de carrera |
| | Requisito explícito del proyecto: la vía es Stored Procedures |

**Descartado** por requisito del proyecto.

### SQL directo en los modelos (sin SP)

Descartado por la misma razón y por la duplicación de lógica transaccional.

### Un SP gigante "sp_todo"

Descartado. Un procedimiento monolítico es imposible de testear, de versionar y de revisar. La granularidad por caso de uso es el punto.

### Triggers en lugar de Stored Procedures

Considerado y **descartado**: los triggers son invisibles en el flujo de aplicación, difíciles de depurar y no se pueden versionar ni probar de forma aislada. Además, MySQL no permite que un trigger llame a un SP con `CALL` de forma portable.

## Consecuencias

**Positivas**
- **Atomicidad garantizada** donde importa: reserva + creación de pedido + líneas, y consumo + cambio de estado + historial.
- El bloqueo de fila (`FOR UPDATE`) vive junto a la escritura, sin cruzar la frontera Node↔MySQL.
- El comportamiento de la base es **auditable sin leer el código de la aplicación**.
- Los SP son reutilizables desde otras herramientas (Workbench, scripts, otros servicios).

**Negativas / costos**
- **El SQL no se puede probar con el runner de Node.** Se necesita una suite de pruebas contra la BD real (`npm run test:db`), con una BD de pruebas aparte.
- El código de aplicación y el SQL evolucionan por separado: un cambio de esquema exige migraciones coordinadas.
- Menos idiomático en JavaScript: los modelos devuelven `resultSets` crudos que hay que mapear a objetos del dominio.
- `SIGNAL` + `MESSAGE_TEXT` para errores de negocio es un poco artesanal, pero es lo que MySQL 8 ofrece de forma portable.

**Impacto en el proyecto**
- `db/schema.sql` (tablas, índices, vistas), `db/procedures/*.sql` (SP), `db/seed.sql` (datos iniciales) — en ese orden.
- `npm run db:migrate` ejecuta los tres en orden; `db:migrate` debe correr **con un usuario con permisos de esquema**, no con `nanai_app`.
- Los modelos en `src/models/` son **finos**: invocan el SP y mapean.
- La verificación de código de error: `sp_error` (helper) o convención de prefijo en el `MESSAGE_TEXT`.

**Nota sobre el despliegue:** el SP se despliega con `db/migrate`, no con el código. Por eso el flujo de despliegue documenta que las migraciones se ejecutan **antes** de reiniciar la aplicación.
