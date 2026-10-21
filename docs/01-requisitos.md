# 01 — Requisitos del Sistema

**Proyecto:** NANAI Miel Orgánica
**Versión del documento:** 1.1 (Fase 1 — Especificación)
**Estado:** Aprobado por el solicitante el 21/10/2026
**Autor:** pnle nanai

**Historial de cambios**

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | 21/10/2026 | Emisión inicial |
| 1.1 | 21/10/2026 | Corrección de RN-01/02/03 según revisión: reserva temporal durante el proceso de pago; el descuento definitivo de stock se liga a una **regla** (estado que consume stock) y no a la acción de aprobar. Se añade RNF de coste sin suscripciones obligatorias y RNF de extensibilidad del motor de precios para descuentos/cupones. |

---

## 1. Propósito y convenciones

Este documento define **qué debe hacer** el sistema y **qué NO debe hacer**. Es la
fuente de verdad del alcance. Toda decisión posterior —arquitectura, modelo de
datos, endpoints, interfaz— debe poder rastrearse hasta un requisito de este
documento. Si una funcionalidad no tiene un RF asociado, no entra.

### 1.1 Convenciones de identificación

| Prefijo | Significado | Formato |
|---|---|---|
| `RF-###` | Requisito Funcional: comportamiento observable del sistema | Entero consecutivo, sin reutilizar |
| `RNF-###` | Requisito No Funcional: calidad, seguridad, rendimiento, mantenibilidad | Ídem |
| `RN-###` | Regla de Negocio: regla del dominio (detallada en `03-reglas-de-negocio.md`) | Ídem |
| `CU-##` | Caso de Uso (detallado en `02-actores-y-casos-de-uso.md`) | Ídem |
| `ADR-###` | Architectural Decision Record (`docs/decisiones/`) | Ídem |

### 1.2 Prioridad

- **Alta** — necesario para que la v1 sea usable por el negocio. Si falta, la v1 no se entrega.
- **Media** — importante, pero entregable en una iteración posterior sin bloquear el negocio.
- **Baja** — deseable; se prioriza solo si hay capacidad.

---

## 2. Descripción del producto

NANAI Miel Orgánica es un emprendimiento peruano que comercializa miel orgánica
en presentación de 250 g y 500 g, con clientes iniciales en **Chiclayo (Lambayeque)**
y proyección de atender otras regiones del Perú.

La plataforma es un **e-commerce con panel administrativo propio** que permite al
vendedor:

1. Publicar y editar productos **sin tocar código** (el catálogo es información
   dinámica, no código).
2. Recibir pedidos por la web con reserva de stock y pago en línea.
3. Registrar ventas presenciales con el **mismo** inventario.
4. Controlar el ciclo de vida de cada pedido con un historial auditable.
5. Reducir el trabajo manual mediante notificaciones automáticas y reportes.

### 2.1 Principio rector: el sistema no se limita a la miel

La miel es el producto inicial, no el modelo. Cualquier producto, categoría,
método de pago, agencia de transporte o canal de venta debe poder añadirse
**desde el panel o desde configuración**, sin modificar el código fuente.

> **Consecuencia arquitectónica directa:** el modelo de datos no contendrá
> columnas como `es_miel_250g`. Contendrá atributos genéricos (`nombre`,
> `precio`, `stock`, `peso_gramos`, `categoria_id`) y tablas de contenido
> extensible (`producto_caracteristicas`, `producto_beneficios`, etc.).

---

## 3. Alcance

### 3.1 Dentro del alcance (v1)

- Catálogo público de productos y categorías, con búsqueda y filtros.
- Carrito de compras en el navegador con múltiples productos y cantidades.
- Checkout sin registro obligatorio del cliente.
- Creación de pedido con **código único consultable** (`NAN-AAAA-NNNNNN`).
- **Reserva temporal de stock** con caducidad automática.
- Pasarela de pagos con tarjeta (procesada por un tercero) + medios manuales
  (Yape/Plin/transferencia) verificados por el vendedor.
- Seguimiento del pedido por código, sin iniciar sesión.
- Panel administrativo protegido para el vendedor.
- Gestión dinámica de productos, categorías, usuarios, roles y parámetros.
- Inventario centralizado con movimientos auditables.
- Venta presencial rápida con emisión de boleta interna.
- Notificaciones por correo desacopladas.
- Dashboard con indicadores y reportes exportables a Excel.

### 3.2 Fuera del alcance de la v1 (explícitamente)

| Excluido | Motivo | Cómo se habilitará después |
|---|---|---|
| Comprobante electrónico ante **SUNAT** | Requiere certificado digital, código de seguridad, proveedor de firma y pruebas de homologación. Es un proyecto con vida propia. | Módulo independiente `integrations/sunat/` con su propia tabla de Issuing. La boleta interna actual **no** es un comprobante válido ante SUNAT. |
| Aplicación móvil | El público objetivo compra por web; duplicar el frontend multiplica el costo de mantenimiento. | La API REST queda diseñada como contrato independiente del canal; una app móvil será un cliente más. |
| Multi-idioma | El mercado inicial es Perú. | Textos centralizados y parametrizables desde el inicio. |
| Multi-marca / multi-tenant | Un solo emprendimiento. | El esquema usa `organizacion_id` solo si el negocio lo requiere; hoy se omite por sobreingeniería. |
| Suscripciones / recurrencia | No aplica al producto actual. | Los productos ya admiten `tipo_venta` y las órdenes, `periodicidad`. |
| Promociones y cupones | El volumen de pedidos aún es bajo. | Tablas de datos + servicio de pricing; el motor de precios se aísla precisamente para esto. |
| Marketplaces | Fuera del modelo de negocio. | — |
| Rastreo GPS en tiempo real | La agencia de transporte ya ofrece seguimiento por código. | URL de seguimiento parametrizada por agencia. |
| Facturación B2B con crédito | No hay clientes corporativos con crédito en la v1. | — |

> **Regla de alcance:** cada exclusión es una **puerta preparada, no un muro**.
> Cuando se active una, debe ser un módulo nuevo, no una reescritura.

---

## 4. Actores (resumen)

| Actor | Tipo | Descripción | En la v1 |
|---|---|---|---|
| Cliente anónimo | Primario | Compra sin registrarse. Consulta su pedido con el código único. | Sí |
| Vendedor / Administrador | Primario | Opera el negocio: catálogo, pedidos, inventario, ventas, configuración. | Sí (1 cuenta) |
| Pasarela de pagos | Externo | Confirma o rechaza pagos; notifica vía webhook. | Sí |
| Proveedor de consulta DNI | Externo | Valida y completa datos de identidad del cliente. | Sí (diferido a Fase 6) |
| Servidor de correo | Externo | Entrega notificaciones a clientes y al vendedor. | Sí |
| Transportista (Shalom y otros) | Externo | Transporta el pedido; aporta código de seguimiento. | Sí (datos, sin API) |
| Cliente registrado | Secundario | Cuenta con historial de pedidos. | No (esquema preparado) |
| Otros administradores con roles | Secundario | Perfiles con permisos distintos. | No (esquema preparado) |

> El detalle completo, los permisos y los casos de uso están en
> `02-actores-y-casos-de-uso.md`.

---

## 5. Requisitos funcionales

### 5.1 Catálogo y contenido público

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-001 | Alta | Listar categorías activas | Devuelve solo categorías con `activo = 1`; las vacías no se listan |
| RF-002 | Alta | Listar productos disponibles con paginación y filtros | Filtra por categoría, disponibilidad y texto; paginado con `total` real |
| RF-003 | Alta | Consultar detalle de producto | Devuelve producto + imágenes + características + beneficios + información de consumo + categoría |
| RF-004 | Media | Mostrar contenido institucional (quiénes somos, valores) | Contenido editable desde el panel, no hardcodeado en el frontend |
| RF-005 | Media | Compartir producto en redes sociales | Metadatos Open Graph y `canonical` correctos por producto |

### 5.2 Carrito

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-006 | Alta | Agregar producto al carrito | Permite múltiples productos distintos y cantidades acumulables |
| RF-007 | Alta | Modificar cantidad de un ítem | Recalcula subtotales; valida contra stock disponible |
| RF-008 | Alta | Eliminar un ítem o vaciar el carrito | El total se recalcula a 0 si se vacía |
| RF-009 | Alta | Calcular totales de forma autoritativa en el servidor | El cliente nunca envía precios; el servidor los obtiene de la BD |
| RF-010 | Media | Persistir el carrito en el navegador | Se restaura al recargar; se invalida si el producto deja de estar disponible |
| RF-011 | Media | Advertir al cliente cuando una cantidad supera el stock disponible | Mensaje claro antes de llegar al checkout |

### 5.3 Checkout y creación de pedido

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-012 | Alta | Capturar datos del cliente sin exigir registro | Se solicitan nombre, DNI (opcional), teléfono, correo y dirección si aplica |
| RF-013 | Media | Consultar DNI contra una API externa | Solo desde el backend; las credenciales nunca llegan al navegador |
| RF-014 | Alta | Seleccionar modalidad de entrega | `ENTREGA_LOCAL` o `ENVIO_AGENCIA`; reglas de validación distintas por modalidad |
| RF-015 | Alta | Calcular el costo de envío | Según zona y modalidad, con umbrales de gratuidad configurables |
| RF-016 | Alta | Crear el pedido y asignar un código único | Código `NAN-AAAA-NNNNNN` único e irrepetible bajo concurrencia |
| RF-017 | Alta | Crear una **reserva temporal de stock** que cubra el proceso de pago | La reserva se crea al crear el pedido, tiene fecha de expiración configurable y reduce el stock *disponible* (no el stock físico) |
| RF-018 | Alta | Liberar automáticamente las reservas expiradas | Proceso programado que cancela el pedido y devuelve el stock a disponible |

### 5.4 Pagos

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-019 | Alta | Iniciar el pago con tarjeta mediante la pasarela | El sistema nunca recibe ni almacena número de tarjeta ni CVV |
| RF-020 | Alta | Registrar pago por Yape, Plin o transferencia | Queda en estado "por verificar" hasta que el vendedor lo confirme |
| RF-021 | Alta | Recibir el webhook de la pasarela | Se valida la firma del webhook; se rechaza la firma inválida |
| RF-022 | Alta | Consultar el estado real del pago en la pasarela | Antes de confirmar un pedido se verifica contra la pasarela, no solo contra el webhook |
| RF-023 | Alta | Prevenir pagos duplicados | Un mismo evento de pago no puede aplicarse dos veces |
| RF-024 | Alta | Confirmar manualmente el pago de medios manuales | Requiere referensi interna y queda registrado en el historial |
| RF-025 | Media | Reintentar un pago fallido | El pedido vuelve a un estado que permita reintentar sin duplicar reservas |

### 5.5 Seguimiento del pedido

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-026 | Alta | Consultar un pedido por su código único | Sin necesidad de sesión ni de credenciales del cliente |
| RF-027 | Alta | Ver el detalle: productos, cantidades, total, estado del pago | Todos los datos coinciden con el pedido almacenado |
| RF-028 | Alta | Ver el historial de estados | Lista cronológica de cada cambio, con fecha, estado anterior y motivo |
| RF-029 | Alta | Ver los datos de envío | Agencia, código de seguimiento, fecha de envío y enlace cuando exista |
| RF-030 | Media | Confirmar la recepción del pedido | Solo cuando el pedido está en un estado que lo permita |
| RF-031 | Media | Ver el motivo del rechazo | El cliente ve por qué fue desaprobado su pedido |

### 5.6 Panel administrativo — acceso y seguridad

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-032 | Alta | Iniciar sesión como administrador | Email + contraseña; la contraseña nunca se almacena en texto plano |
| RF-033 | Alta | Cerrar sesión | La sesión del servidor se invalida; la cookie se elimina |
| RF-034 | Alta | Recuperar contraseña con código temporal | Flujo: correo → código → verificación → nueva contraseña; el código caduca y es de un solo uso |
| RF-035 | Alta | Proteger las rutas del panel | Sin sesión válida, el acceso se rechaza con 401 |
| RF-036 | Media | Limitar los intentos de acceso y de recuperación | Se bloquea temporalmente ante exceso de intentos |
| RF-037 | Media | Gestionar usuarios y roles | El esquema y la autorización por rol existen desde el inicio, aunque la interfaz sea mínima en la v1 |

### 5.7 Panel administrativo — catálogo

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-038 | Alta | Crear, editar, listar y desactivar productos | Sin tocar código; los datos se guardan en BD |
| RF-039 | Alta | Crear, editar y ordenar categorías | Orden configurable; una categoría con productos no se elimina, se desactiva |
| RF-040 | Alta | Adjuntar imágenes a un producto | Varias imágenes, con portada e orden; se almacenan fuera de MySQL |
| RF-041 | Alta | Administrar características, beneficios e información de consumo | Listas dinámicas por producto, editables desde el panel |
| RF-042 | Alta | Gestionar precio, peso/presentación, disponibilidad y stock inicial | El stock inicial genera el primer movimiento de inventario |
| RF-043 | Media | Advertir sobre afirmaciones de salud | El panel exige confirmación explícita de que el contenido no presenta el producto como tratamiento médico |

### 5.8 Panel administrativo — pedidos y entregas

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-044 | Alta | Listar pedidos con filtros | Por estado, fecha, tipo de venta, modalidad de entrega y búsqueda por código |
| RF-045 | Alta | Ver el detalle completo de un pedido | Incluye cliente, ítems, pagos, historial y envío |
| RF-046 | Alta | Aprobar un pedido | Solo desde un estado que lo permita; genera notificación al cliente |
| RF-047 | Alta | Desaprobar un pedido con motivo | El motivo es obligatorio, se guarda y se muestra al cliente |
| RF-048 | Alta | Cambiar el estado de un pedido según la máquina de estados | Las transiciones inválidas se rechazan con un error explicativo |
| RF-049 | Media | Registrar datos de envío | Agencia, código de seguimiento, fecha de envío y enlace opcional |
| RF-050 | Media | Gestionar agencias de transporte | Catálogo administrable; el sistema no depende de un único transportista |

### 5.9 Panel administrativo — inventario

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-051 | Alta | Registrar un ingreso de productos | Ej.: ingresan 50 unidades → aumenta el stock y queda el movimiento registrado |
| RF-052 | Alta | Registrar ajustes, mermas y devoluciones | Todo ajuste queda justificado y auditado |
| RF-053 | Alta | Consultar el historial de movimientos | Producto, cantidad, tipo, fecha, usuario y origen de cada movimiento |
| RF-054 | Media | Alertar sobre stock bajo | Umbral configurable por producto o global |
| RF-055 | Alta | Inventario único para ventas online y presenciales | Ambas canales consumen el mismo stock; no hay.existencias paralelas |

### 5.10 Panel administrativo — ventas presenciales

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-056 | Alta | Registrar una venta presencial rápida | Selección de productos y cantidades; no exige datos de cliente |
| RF-057 | Alta | Cobrar y emitir boleta interna | Se registra el medio de pago y se genera un comprobante imprimible |
| RF-058 | Media | Consultar el historial de ventas | Con filtro por fecha y medio de pago |

### 5.11 Dashboard, reportes y configuración

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-059 | Media | Dashboard con indicadores | Ventas, ingresos, pedidos pendientes, por aprobar, stock bajo y productos más vendidos |
| RF-060 | Media | Reportes de ventas, ingresos, productos e inventario | Filtrables por rango de fechas y tipo de venta |
| RF-061 | Media | Exportar reportes a Excel | La lógica de exportación no vive en los controladores |
| RF-062 | Alta | Configurar parámetros del negocio | IGV, TTL de reserva, costo de envío, umbral de stock bajo, etc. |
| RF-063 | Media | Configurar el canal de correo y las plantillas de notificación | Cambiar de proveedor no exige tocar código |

### 5.12 Notificaciones

| ID | Pri. | Requisito | Criterio de aceptación |
|---|---|---|---|
| RF-064 | Alta | Notificar al cliente los eventos clave del pedido | Registro, pago confirmado, aprobado, desaprobado, en preparación, enviado, recibido/completado |
| RF-065 | Alta | Notificar al vendedor de pedidos nuevos y acciones pendientes | Aviso de pedido recibido y de pedido pendiente de aprobación |
| RF-066 | Alta | Envío de correo desacoplado y reutilizable | Un servicio central; ningún controlador envía correo directamente |
| RF-067 | Media | Notificar la recuperación de contraseña | El correo nunca contiene la contraseña actual |

---

## 6. Requisitos no funcionales

### 6.1 Seguridad

| ID | Requisito |
|---|---|
| RNF-001 | Las contraseñas se almacenan con **Argon2id** (`@node-rs/argon2`), nunca en texto plano ni cifradas de forma reversible |
| RNF-002 | Los secretos (MySQL, pasarela de pagos, API de DNI, correo, firma de webhook) viven **solo** en variables de entorno. Ningún secreto se versiona |
| RNF-003 | La aplicación se conecta a MySQL con un usuario de **privilegios mínimos** (no `root`) |
| RNF-004 | Sesiones con cookie `httpOnly`, `SameSite=Lax`, `Secure` en producción, y expiración por inactividad |
| RNF-005 | Protección **CSRF** en todas las operaciones de escritura del panel |
| RNF-006 | Limitación de tasa (rate limiting) por IP en login, recuperación de contraseña, creación de pedidos y webhooks |
| RNF-007 | Cabeceras de seguridad mediante Helmet, incluida una CSP que no permita `unsafe-inline` en scripts |
| RNF-008 | Validación de **todas** las entradas en el backend, con esquemas; nunca se confía en el frontend |
| RNF-009 | Consultas SQL **parametrizadas** en todos los casos; concatenación de strings prohibida |
| RNF-010 | Los errores en producción no exponen stack traces, SQL, rutas internas ni credenciales |
| RNF-011 | Los datos personales del cliente (DNI, nombre, dirección) se registran en logs solo de forma parcial (enmascarada) |
| RNF-012 | Cumplimiento de la **Ley N.º 29733** (Protección de Datos Personales, Perú): consentimiento, finalidad declarada y minimización de datos |

### 6.2 Rendimiento y escalabilidad

| ID | Requisito |
|---|---|
| RNF-013 | El catálogo paginado responde en **< 300 ms (p95)** con hasta 1 000 productos activos |
| RNF-014 | Ninguna consulta de listado devuelve la tabla completa sin paginación |
| RNF-015 | El stock permanece correcto ante **ventas concurrentes** del mismo producto (prueba de concurrencia obligatoria) |
| RNF-016 | El dashboard se obtiene con un **número acotado de consultas**, no con una por widget |
| RNF-017 | Las imágenes se sirven como archivos estáticos, no incrustadas en la base de datos |

### 6.3 Integridad de datos

| ID | Requisito |
|---|---|
| RNF-018 | Toda operación que implique más de una escritura se ejecuta dentro de una **transacción** con `COMMIT`/`ROLLBACK` |
| RNF-019 | Todo cambio de stock deja un movimiento en `inventory_movements` en la **misma** transacción |
| RNF-020 | Todo cambio de estado de pedido deja un registro en el historial en la **misma** transacción |
| RNF-021 | Integridad referencial con claves foráneas `RESTRICT` en las relaciones de integridad y `CASCADE` solo en las de dependencia fuerte |
| RNF-022 | Los importes se almacenan como `DECIMAL(10,2)` en soles. **Nunca** con tipos de coma flotante |
| RNF-023 | Los códigos de pedido y de venta son únicos, garantizados por el motor de la BD |

### 6.4 Mantenibilidad y calidad

| ID | Requisito |
|---|---|
| RNF-024 | Separación de responsabilidades: rutas → controladores → servicios → modelos → BD |
| RNF-025 | **Ninguna** lógica de negocio en rutas, controladores, vistas ni SQL disperso en el código |
| RNF-026 | **Ninguna** consulta SQL escrita directamente en un controlador |
| RNF-027 | Código sin duplicación: la lógica compartida vive en servicios o utilidades |
| RNF-028 | Convenciones de código automáticas y verificación antes de cada commit |
| RNF-029 | Pruebas unitarias para servicios críticos (cálculo de totales, máquina de estados, stock) |
| RNF-030 | Documentación progresiva y actualizada: requisitos, arquitectura, API, BD, seguridad |
| RNF-041 | **El motor de precios es un servicio aislado** con proveedores de descuento enchufables. En la v1 la lista de proveedores de descuento está vacía, pero la interfaz existe |
| RNF-042 | Las líneas de pedido almacenan el **snapshot** del precio unitario, del descuento aplicado y del subtotal. Incorporar cupones o promociones después **no** obliga a modificar productos, carrito, pedidos ni pagos, ni a migrar los pedidos históricos |
| RNF-043 | Cada integración externa (pasarela de pagos, consulta de DNI, correo, almacenamiento) se implementa como un **adaptador con contrato estable**. Cambiar de proveedor no debe afectar a los módulos que lo consumen |

### 6.5 Usabilidad y compatibilidad

| ID | Requisito |
|---|---|
| RNF-031 | HTML semántico y accesible: etiquetas `<label>`, contraste AA, navegación por teclado |
| RNF-032 | Compatible con las dos últimas versiones de Chrome, Firefox, Edge y Safari; y con móviles |
| RNF-033 | Formato regional peruano: es-PE, moneda PEN (S/), fecha dd/mm/aaaa, IGV 18 % |
| RNF-034 | El panel administrativo debe reducir el trabajo manual del vendedor frente a la gestión sin sistema |

### 6.6 Operación

| ID | Requisito |
|---|---|
| RNF-035 | Endpoint de salud que informa el estado de la aplicación y de la base de datos |
| RNF-036 | Logs estructurados con nivel, marca temporal, identificador de petición y contexto |
| RNF-037 | Apagado ordenado: al recibir `SIGTERM` se cierran las conexiones y el servidor |
| RNF-038 | Toda la configuración externa por variables de entorno; ningún valor sensible en el código |
| RNF-039 | Procedimiento documentado de copia de seguridad de la base de datos |
| RNF-040 | El proyecto se puede levantar desde cero siguiendo `docs/08-instalacion.md` |
| RNF-044 | **La v1 no exige planes mensuales, cuotas fijas ni suscripciones obligatorias** de ningún proveedor. Se priorizan opciones con plan gratuito, pago por uso o recursos locales del propio negocio |
| RNF-045 | Los costos variables por transacción (comisiones de pasarela, créditos de API) se **documentan y se comparan** antes de integrar el proveedor, y quedan registrados en la decisión de arquitectura correspondiente |

---

## 7. Restricciones

| # | Restricción | Impacto |
|---|---|---|
| 1 | **Sin frameworks de frontend** en la v1 (ni React, Vue ni Angular) | El HTML/CSS/JS se escribe a mano; se prioriza JavaScript moderno en módulos ES nativos |
| 2 | **MySQL como único motor** | Se usan las capacidades propias de MySQL 8: procedimientos almacenados, triggers solo justificados, `DECIMAL`, `JSON`, `utf8mb4` |
| 3 | **Node.js y Express** como plataforma backend | Se aprovechan el manejointegrado de errores de Express 5 y los módulos ES nativos |
| 4 | **Un único vendedor en la v1** | Aun así se implementan usuarios, roles y permisos, porque el coste de añadirlos después es mayor |
| 5 | **Clientes en Chiclayo** | Las zonas de entrega local se parametriza; el envío por agencia cubre el resto del Perú |
| 6 | **La pasarela de pagos es un tercero** | El sistema nunca almacena datos de tarjeta; solo recibe el resultado del pago |
| 7 | **RENIEC no ofrece API pública** | La consulta de DNI usa un intermediario; el adaptador está desacoplado para poder cambiarlo |
| 8 | **Red university con inspección TLS (proxy Fortinet)** | Las credenciales de terceros viajan a través de un proxy que inspecciona el tráfico: fuera de producción, rotar claves y considerar una red de confianza |
| 9 | **Boleta interna ≠ comprobante SUNAT** | El sistema no emite comprobantes electrónicos oficiales en la v1 |
| 10 | **Sin planes mensuales ni suscripciones obligatorias** | En la v1 no se contrata hosting de pago, ni planes de correo, ni almacenamiento cloud de pago, ni servicios con cuota mensual. Se usan recursos locales o planes gratuitos. El único costo recurrente admisible es el que el negocio pueda cancelar sin justificar (p. ej. dominio, y en su momento el hosting real). Las **comisiones por transacción** (pasarela de pagos, créditos de API de DNI) se evalúan y documentan en la Fase de Pagos |

---

## 8. Supuestos

| # | Supuesto | Si resulta falso |
|---|---|---|
| S-01 | El cliente compra sin cuenta; el código del pedido es su credencial de consulta | Habría que añadir un módulo de registro/login de clientes |
| S-02 | El pago con tarjeta se resuelve con una pasarela con sandbox y webhooks firmados | Habría que evaluar un flujo de redirección por link de pago |
| S-03 | El stock se descuenta al confirmar el pago, no al crear el pedido | Cambiaría RF-017/RF-018 y la máquina de estados; el diseño de reserva lo permite |
| S-04 | Las boletas de la v1 son internas y de uso administrativo | Activaría el módulo `integrations/sunat/` |
| S-05 | El volumen inicial es bajo (decenas de pedidos/mes) | Las consultas ya están paginadas e indexadas, por lo que el crecimiento es lineal |
| S-06 | La consulta de DNI es opcional en el checkout | Puede volverse obligatoria sin cambios de esquema |
| S-07 | El middlewareware de correo funciona con un proveedor SMTP transaccional | El adaptador de correo ya es intercambiable |
| S-08 | El precio mostrado ya incluye IGV | Si se cambiara, el motor de precios se ajusta en un solo servicio |

---

## 9. Reglas de negocio de alto nivel (resumen)

> El detalle, la numeración completa y los casos límite están en
> `03-reglas-de-negocio.md`. Aquí solo se fija la essence para que arquitectura y
> base de datos hereden la misma verdad.

| ID | Regla resumida |
|---|---|
| RN-01 | El carrito es **selección en el navegador**: no crea venta, no reserva stock y no descuenta stock. |
| RN-02 | Al crear el pedido se crea una **reserva temporal de stock** que cubre el proceso de pago. La reserva caduca a los **30 minutos** (configurable); al expirar, el pedido se cancela y el stock vuelve a estar disponible. |
| RN-03 | El **descuento definitivo** del stock no está atado a una acción concreta del vendedor, sino a una **regla**: se produce cuando el pedido entra en un estado marcado como `consume_stock` en el catálogo de estados. |
| RN-04 | Un estado marcado como `libera_stock` devuelve las unidades reservadas al stock disponible. Todo pedido cancelado o desaprobado libera stock. |
| RN-05 | Toda modificación de stock genera un movimiento de inventario trazable, en la **misma transacción** que la operación que la origina. |
| RN-06 | Todo cambio de estado de pedido se registra en el historial; el estado anterior nunca se sobrescribe sin dejar rastro. |
| RN-07 | La máquina de estados se define en **datos**: catálogo de estados + tabla de transiciones. Cada transición declara sus efectos (`consume_stock`, `libera_stock`, `exige_motivo`, `notifica_cliente`, `notifica_vendedor`). Agregar un estado es un `INSERT`, no un despliegue. |
| RN-08 | Las transiciones inválidas se rechazan; el sistema nunca deja un pedido en un estado inconsistente. |
| RN-09 | El código de pedido (`NAN-AAAA-NNNNNN`) se genera con un contador bloqueado; nunca con `MAX(id)+1`. |
| RN-10 | El cliente puede consultar su pedido únicamente con el código, sin credenciales. |
| RN-11 | Un pago aprobado es idempotente: aplicarlo dos veces no duplica stock ni historial. |
| RN-12 | La venta presencial usa el mismo inventario y el mismo motor de totales que la venta online, y descuenta stock definitivo en el momento de su confirmación. |
| RN-13 | El motivo del rechazo de un pedido es obligatorio y visible para el cliente. |
| RN-14 | Los importes son `DECIMAL(10,2)` en PEN e incluyen IGV 18 %. |
| RN-15 | Los pedidos online y presenciales se distinguen por `tipo_venta` pero comparten la misma tabla de cabecera y detalle. |
| RN-16 | Los datos de envío (agencia, código, fecha) se registran **fuera** del flujo de venta, en el módulo de entrega. |

---

## 10. Glosario

| Término | Definición |
|---|---|
| **Boleta interna** | Comprobante interno generado por el sistema. **No** es un comprobante electrónico válido ante SUNAT |
| **Carrito** | Selección temporal de productos en el navegador. No tiene existencia en la base de datos ni reserva stock |
| **Código de pedido** | Identificador legible y único del pedido, con formato `NAN-AAAA-NNNNNN` |
| **Entrega local** | Modalidad en la que el vendedor entrega el pedido en un punto de la ciudad, dentro de una zona configurable |
| **Envío por agencia** | Modalidad en la que un transportista (Shalom u otro) lleva el pedido a destino |
| **IGV** | Impuesto General a las Ventas (18 % en Perú) |
| **Merma** | Pérdida de mercadería por rotura, deterioro o vencimiento |
| **Movimiento de inventario** | Registro auditable de cualquier cambio de stock (ingreso, salida, ajuste, merma) |
| **Origen de movimiento** | Motivo que explica el movimiento: venta online, venta presencial, ingreso a almacén, ajuste manual, devolución, expiración de reserva |
| **Pasarela de pagos** | Proveedor externo que procesa el pago con tarjeta y notifica el resultado |
| **Pedido** | Solicitud de compra del cliente con código único, estados e historial |
| **Producto** | Bien comercializable, con precio, stock, contenido e imágenes. **No** equivale a un frasco de miel |
| **Reserva** | Bloqueo temporal de stock asociado a un pedido no pagado |
| **Rol** | Conjunto de permisos asignables a un usuario del panel |
| **Venta presencial** | Venta registrada por el vendedor en el local, sin cliente registrado, con el mismo inventario |
| **Webhook** | Notificación HTTP que envía la pasarela de pagos al sistema cuando cambia el estado de un pago |

---

## 11. Criterios de aceptación de la v1

La versión 1 se considera entregada cuando:

1. Un cliente puede comprar un producto con tarjeta, recibir un código único y rastrear su pedido hasta "Recibido" **sin crear cuenta**.
2. Un cliente que paga por Yape puede registrar el pago y ser notificado cuando el vendedor lo verifica.
3. El vendedor puede aprobar y desaprobar pedidos, y el motivo del rechazo llega al cliente.
4. El vendedor puede registrar un ingreso de stock y ver el movimiento correspondiente.
5. El vendedor puede registrar una venta presencial y ver el stock actualizado y una boleta imprimible.
6. El vendedor puede crear un producto nuevo con precio, stock e imagen **sin tocar código**.
7. Un pedido no pagado se cancela solo al expirar su reserva y el stock vuelve a estar disponible.
8. El stock solo se descuenta cuando el pedido entra en un estado que consume stock, y ese descuento **es reversible** si el pedido pasa a un estado que libera stock. Cambiar esa asignación es una actualización de datos, no de código.
9. No existe ningún secreto en el repositorio y el historial de Git lo demuestra.
10. Ninguna integración de la v1 exige un plan mensual o una suscripción obligatoria.
11. La suite de pruebas de stock concurrente pasa.

---

## 12. Trazabilidad

Esta tabla se completa a medida que se implementen las fases. Permite auditar que
no exista funcionalidad sin requisito ni requisito sin implementación.

| RF | Caso de uso | Endpoint | Módulo | Estado |
|---|---|---|---|---|
| RF-002 | CU-01 | `GET /api/v1/products` | catálogo | Pendiente |
| RF-016 | CU-05 | `POST /api/v1/orders` | pedidos | Pendiente |
| RF-026 | CU-07 | `GET /api/v1/orders/:code` | seguimiento | Pendiente |

> **Estado de avance del proyecto:** Fase 1 (especificación) en curso.
