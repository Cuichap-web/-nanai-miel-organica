# 06 — API REST

**Proyecto:** NANAI Miel Orgánica  
**Versión:** 1.0 (Fase 1 — Especificación)  
**Estado:** En revisión  
**Base URL:** `/api/v1`  
**Formato:** `application/json`  
**Autenticación:** Sesión en servidor (cookie `httpOnly`) para rutas `/admin/*`.  
**Público:** Sin registro obligatorio para comprar/consultar por código.

---

## 1. Convenciones generales

| Regla | Detalle |
|---|---|
| **Versionado** | Todas las rutas bajo `/api/v1`. Si hay cambio incompatible se crea `/api/v2`. |
| **Métodos HTTP** | `GET` lectura, `POST` creación/acciones, `PUT/PATCH` actualización, `DELETE` desactivación lógica (cuando aplique). |
| **Respuestas exitosas** | Siempre con estructura coherente. Evitar devolver arrays crudos sin contexto cuando hay paginación. |
| **Respuestas con error** | Usar el formato único del manejador central (ver §5). |
| **Idiomas/fechas** | `es-PE`. Fechas en ISO 8601 (`YYYY-MM-DDTHH:mm:ssZ` o local acordado). |
| **Moneda** | `PEN`. Importes con 2 decimales. Precios **con IGV 18% incluido**. |
| **Paginación** | Por query: `page`, `limit`. Defaults razonables. `limit` acotado. |
| **Idempotencia** | `POST /orders` acepta header `Idempotency-Key: <uuid-v4>`. Crítico para evitar duplicados. |
| **Rate limiting** | Aplicado a: `POST /auth/login`, `POST /auth/recuperar`, `POST /orders`, `POST /payments/webhook`. |
| **PII** | En logs se enmascara. Nunca exponer contraseñas, tokens, claves ni datos de tarjeta. |

### 1.1 Respuesta exitosa base

```json
{
  "success": true,
  "data": { ... },
  "meta": { ... }  // opcional
}
```

### 1.2 Paginación

**Query params:**

| Param | Tipo | Default | Máx. | Notas |
|---|---|---|---|---|
| `page` | int | 1 | — | >= 1 |
| `limit` | int | 12 | 50 | Afecta catálogo/publico. Panel puede usar hasta 100 con justificación. |

**Respuesta:**

```json
{
  "success": true,
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 12,
    "total": 24,
    "totalPages": 2,
    "hasNext": true,
    "hasPrev": false
  }
}
```

---

## 2. Rutas públicas

### 2.1 Catálogo

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/categories` | No | Listar categorías activas ordenadas por `orden`. | RF-001 |
| `GET` | `/products` | No | Listar productos disponibles con paginación/filtros. | RF-002 |
| `GET` | `/products/:slug` | No | Detalle de producto (imágenes, características, beneficios, uso). | RF-003 |
| `GET` | `/pages/:slug` | No | Contenido institucional editable. | RF-004 |

**Ejemplo `GET /products`:**

```http
GET /api/v1/products?categoria=miel&buscar=500&page=1&limit=12
```

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "nombre": "Miel Orgánica 500 g",
      "slug": "miel-organica-500g",
      "precio": 59.90,
      "peso_grs": 500,
      "imagen_portada": "/storage/products/miel-500g-portada.jpg",
      "disponible": true,
      "categoria": { "id": 1, "nombre": "Miel", "slug": "miel" }
    }
  ],
  "meta": { "page": 1, "limit": 12, "total": 2, "totalPages": 1, "hasNext": false, "hasPrev": false }
}
```

> `disponible` se calcula como `stock_fisico - reservas_vigentes`. El servidor nunca expone `stock_fisico` crudo al público.

### 2.2 Carrito (validación autoritativa)

El carrito vive en `localStorage` del cliente. El servidor **valida y recalcula** siempre.

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/cart/validate` | No | Validar ítems contra BD: precios vigentes, stock disponible, producto activo. Devuelve totales con IGV incluido. | RF-009, RF-011 |

**Body:**

```json
{
  "items": [
    { "producto_id": 1, "cantidad": 2 },
    { "producto_id": 2, "cantidad": 1 }
  ]
}
```

**Respuesta:**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "producto_id": 1,
        "nombre": "Miel Orgánica 500 g",
        "precio_unitario": 59.90,
        "cantidad": 2,
        "subtotal_linea": 119.80,
        "disponible_actual": 15,
        "valido": true
      }
    ],
    "subtotal": 149.70,
    "costo_envio": 0.00,
    "total": 149.70,
    "moneda": "PEN",
    "igv_incluido": true
  }
}
```

Si algún ítem es inválido, se marca `valido: false` con `motivo`. El frontend no debe permitir continuar con ítems inválidos.

### 2.3 Pedidos

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/orders` | No | Crear pedido. Genera código `NAN-YYYY-NNNNNN`, crea **reserva temporal** (cubre proceso de pago), guarda snapshot. Requiere `Idempotency-Key`. | RF-012–RF-018 |
| `GET` | `/orders/track/:codigo` | No | Consultar pedido por código único. Sin login. | RF-026–RF-031 |
| `POST` | `/orders/:codigo/confirm-received` | No | Confirmar recepción cuando aplique. | RF-030 |

**`POST /orders` body:**

```json
{
  "items": [
    { "producto_id": 1, "cantidad": 2 }
  ],
  "cliente": {
    "nombre": "Juan Pérez",
    "email": "juan@example.com",
    "telefono": "999999999",
    "dni": "12345678",
    "direccion": "Av. Ejemplo 123",
    "zona_distrito": "Chiclayo"
  },
  "modalidad_entrega": "ENTREGA_LOCAL",
  "metodo_pago": "TARJETA"
}
```

**Respuesta exitosa:**

```json
{
  "success": true,
  "data": {
    "pedido_id": 125,
    "codigo": "NAN-2026-000125",
    "estado": "PENDIENTE_PAGO",
    "total": 149.70,
    "reserva_expira_en": "2026-10-21T18:00:00Z",
    "url_seguimiento": "/seguimiento/NAN-2026-000125",
    "pasarela": {
      "requerido": true,
      "intencion_pago_url": "/api/v1/payments/init"
    }
  }
}
```

**`GET /orders/track/NAN-2026-000125` respuesta (resumida):**

```json
{
  "success": true,
  "data": {
    "codigo": "NAN-2026-000125",
    "estado_actual": { "codigo": "PAGADO", "nombre": "Pagado" },
    "historial": [
      { "estado": "PENDIENTE_PAGO", "fecha": "2026-10-21T17:30:00Z", "motivo": null },
      { "estado": "PAGADO", "fecha": "2026-10-21T17:35:00Z", "motivo": null }
    ],
    "items": [ ... ],
    "totales": { "subtotal": 149.70, "costo_envio": 0.00, "total": 149.70 },
    "pago": { "estado": "APROBADO", "proveedor": "TARJETA" },
    "envio": { "agencia": null, "codigo_seguimiento": null, "fecha_envio": null },
    "motivo_desaprobacion": null
  }
}
```

> Nunca se devuelven datos completos de contacto. Se ocultan parcialmente para evitar filtrado.

### 2.4 Pagos

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/payments/init` | No | Iniciar intención de pago con tarjeta. Devuelve datos para redirección/formulario seguro del proveedor. | RF-019 |
| `POST` | `/payments/manual` | No | Registrar intención de pago manual (Yape/Plin/Transferencia). Pasa a `PAGO_POR_VERIFICAR`. | RF-020 |
| `POST` | `/payments/webhook` | No* | Webhook de la pasarela. **Firma obligatoria**. Idempotente por `provider_event_id`. | RF-021–RF-023 |

\* Requiere validación de firma, no sesión. Rate limiting estricto.

**`POST /payments/manual`:**

```json
{
  "codigo_pedido": "NAN-2026-000125",
  "proveedor": "YAPE",
  "referencia_interna": "OP-123456"
}
```

**Respuesta:**

```json
{
  "success": true,
  "data": {
    "pedido_codigo": "NAN-2026-000125",
    "estado": "PAGO_POR_VERIFICAR",
    "mensaje": "Registramos tu intención de pago. El vendedor lo verificará a la brevedad."
  }
}
```

**`POST /payments/webhook` (cabeceras relevantes):**

```http
X-Signature: <firma>
X-Event-Id: <id_evento_proveedor>
Content-Type: application/json
```

El handler **valida firma**, **verifica estado real contra pasarela**, **aplica idempotencia** y **solo entonces** transiciona estados. En caso de firma inválida → `401` sin detalles sensibles.

### 2.5 DNI (opcional y tolerante a fallos)

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/dni/consulta` | No | Consultar DNI desde backend hacia adaptador. Autocompletado opcional. | RF-013 |

**Body:**

```json
{
  "dni": "12345678"
}
```

**Respuesta (éxito):**

```json
{
  "success": true,
  "data": {
    "dni": "12345678",
    "nombres": "JUAN CARLOS",
    "apellido_paterno": "PEREZ",
    "apellido_materno": "LOPEZ",
    "nombre_completo": "JUAN CARLOS PEREZ LOPEZ"
  }
}
```

Si el proveedor falla/agota créditos/timeout → `200` con `data: null` y mensaje informativo. **El checkout NO se bloquea**.

---

## 3. Rutas de autenticación (panel)

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/auth/login` | No | Iniciar sesión. Rate limit estricto. | RF-032 |
| `POST` | `/auth/logout` | Sí (sesión) | Cerrar sesión e invalidar cookie. | RF-033 |
| `POST` | `/auth/recuperar` | No | Solicitar código de recuperación. Respuesta idéntica exista o no el correo. | RF-034 |
| `POST` | `/auth/recuperar/verificar` | No | Verificar código y establecer nueva contraseña. | RF-034 |
| `GET` | `/auth/me` | Sí | Datos del usuario autenticado + roles/permisos. | RF-035 |

**`POST /auth/login`:**

```json
{
  "email": "admin@nanai.pe",
  "password": "********"
}
```

**Respuesta:**

```json
{
  "success": true,
  "data": {
    "user": { "id": 1, "nombre": "pnle nanai", "email": "luiscuichap@gmail.com" },
    "roles": ["ADMIN"]
  }
}
```

Cookie: `Set-Cookie: nanai_session=<id>; HttpOnly; SameSite=Lax; Path=/; Max-Age=...` (Secure en producción)

---

## 4. Rutas administrativas (`/admin`)

Todas requieren sesión válida. Autorización por rol/permisos cuando aplique.

### 4.1 Dashboard

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/admin/dashboard` | Sí | Indicadores: ventas, ingresos, pedidos pendientes, por aprobar, stock bajo, más vendidos. | RF-059 |

### 4.2 Productos y categorías

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/admin/categorias` | Sí | Listar categorías | RF-039 |
| `POST` | `/admin/categorias` | Sí | Crear categoría | RF-039 |
| `PUT` | `/admin/categorias/:id` | Sí | Editar categoría | RF-039 |
| `PATCH` | `/admin/categorias/:id/toggle` | Sí | Activar/desactivar | RF-039 |
| `GET` | `/admin/productos` | Sí | Listar productos (con stock, activo) | RF-038 |
| `POST` | `/admin/productos` | Sí | Crear producto dinámico | RF-038 |
| `GET` | `/admin/productos/:id` | Sí | Detalle completo | RF-038 |
| `PUT` | `/admin/productos/:id` | Sí | Editar producto | RF-038 |
| `PATCH` | `/admin/productos/:id/toggle` | Sí | Activar/desactivar | RF-038 |
| `POST` | `/admin/productos/:id/imagenes` | Sí | Subir imágenes (multipart). Almacenamiento local hoy, intercambiable. | RF-040 |
| `POST` | `/admin/productos/:id/caracteristicas` | Sí | Agregar características | RF-041 |
| `POST` | `/admin/productos/:id/beneficios` | Sí | Agregar beneficios (con advertencia de salud) | RF-041, RF-043 |
| `POST` | `/admin/productos/:id/uso` | Sí | Agregar información de consumo/uso | RF-041 |

### 4.3 Pedidos

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/admin/pedidos` | Sí | Listado con filtros (estado, tipo, fecha, código). | RF-044 |
| `GET` | `/admin/pedidos/:id` | Sí | Detalle completo (cliente, items, pagos, historial, envío). | RF-045 |
| `POST` | `/admin/pedidos/:id/aprobar` | Sí | **Aprobar**. Transición válida. Si consume stock → consume en transacción. | RF-046, RN-03 |
| `POST` | `/admin/pedidos/:id/desaprobar` | Sí | **Desaprobar con motivo obligatorio**. Libera reserva si aplica. | RF-047, RN-04, RN-13 |
| `POST` | `/admin/pedidos/:id/cambiar-estado` | Sí | Cambiar estado según transición permitida. | RF-048 |
| `POST` | `/admin/pedidos/:id/envio` | Sí | Registrar agencia, código, fecha, enlace. | RF-049 |
| `POST` | `/admin/pedidos/:id/pago/verificar` | Sí | Verificar pago manual Yape/Plin/Transferencia. | RF-024 |
| `POST` | `/admin/pedidos/:id/pago/rechazar` | Sí | Rechazar pago manual (vuelve a `PENDIENTE_PAGO` si reserva vigente). | RF-024 |

**`POST /admin/pedidos/:id/desaprobar`:**

```json
{
  "motivo": "Stock insuficiente para cubrir el pedido"
}
```

Si `motivo` vacío → `400` con `code: MOTIVO_OBLIGATORIO`.

**`POST /admin/pedidos/:id/aprobar`:**

Sin body obligatorio. El servicio valida: pago confirmado, transición válida, reserva suficiente. Si pasa a `APROBADO` con `consume_stock=1`, ejecuta consumo en la misma transacción.

### 4.4 Inventario

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/admin/inventario` | Sí | Stock por producto (físico + reservado + disponible calculado). | RF-051–RF-055 |
| `POST` | `/admin/inventario/ingreso` | Sí | Registrar ingreso. Suma a `stock_fisico`, genera movimiento `INGRESO`. | RF-051 |
| `POST` | `/admin/inventario/ajuste` | Sí | Ajuste/merma con **justificación obligatoria**. | RF-052 |
| `GET` | `/admin/inventario/movimientos` | Sí | Historial con filtros por producto/origen/fecha. | RF-053 |
| `GET` | `/admin/inventario/alertas` | Sí | Productos con `stock_fisico - reservado < umbral`. | RF-054 |

**`POST /admin/inventario/ingreso`:**

```json
{
  "producto_id": 1,
  "cantidad": 50,
  "motivo": "Compra a proveedor"
}
```

### 4.5 Ventas presenciales

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `POST` | `/admin/ventas-presenciales` | Sí | Registrar venta rápida. Sin cliente obligatorio. Consume stock inmediato. | RF-056, RF-057 |
| `GET` | `/admin/ventas-presenciales` | Sí | Historial de ventas presenciales. | RF-058 |
| `GET` | `/admin/ventas-presenciales/:id/boleta` | Sí | Boleta interna imprimible. | RF-057 |

**`POST /admin/ventas-presenciales`:**

```json
{
  "items": [
    { "producto_id": 1, "cantidad": 1 }
  ],
  "medio_pago": "EFECTIVO",
  "cliente_nombre": null,
  "notas": null
}
```

Respuesta incluye `venta_id`, `codigo`, `total`, `boleta_url`.

### 4.6 Reportes, configuración, usuarios

| Método | Ruta | Auth | Descripción | RF |
|---|---|---|---|---|
| `GET` | `/admin/reportes/ventas` | Sí | Reporte de ventas con filtros por fecha/tipo. | RF-060 |
| `GET` | `/admin/reportes/inventario` | Sí | Reporte de inventario y movimientos. | RF-060 |
| `GET` | `/admin/reportes/exportar/excel` | Sí | Exportar a Excel (desacoplado de controladores). | RF-061 |
| `GET` | `/admin/configuracion` | Sí | Parámetros (`settings`). | RF-062 |
| `PUT` | `/admin/configuracion` | Sí | Actualizar parámetros editables. | RF-062 |
| `GET` | `/admin/usuarios` | Sí | Usuarios, roles. Esquema preparado. | RF-037 |
| `GET` | `/admin/agencias` | Sí | Agencias de transporte. | RF-050 |

---

## 5. Catálogo de errores

Todos los errores usan este formato.

```json
{
  "success": false,
  "error": {
    "code": "CODIGO_MAQUINA",
    "message": "Mensaje claro para el cliente",
    "details": { ... } // opcional, solo info útil
  }
}
```

### Errores comunes

| Código | HTTP | Cuándo | Notas |
|---|---|---|---|
| `VALIDACION_FALLIDA` | 400 | Zod falla | `details` con campos/errores |
| `DATOS_INCOMPLETOS` | 400 | Faltan datos obligatorios | Específico por campo |
| `MOTIVO_OBLIGATORIO` | 400 | Desaprobar sin motivo | Cumple RN-13 |
| `NO_AUTENTICADO` | 401 | Sin sesión | Redirigir a login |
| `SESION_EXPIRADA` | 401 | Sesión caducada | Limpiar cookie |
| `SIN_PERMISO` | 403 | Sin permisos | No revelar ruta |
| `NO_ENCONTRADO` | 404 | Recurso no existe | Genérico |
| `PEDIDO_NO_ENCONTRADO` | 404 | Código inválido o no existe | Respuesta genérica (evita enumeración) |
| `TRANSICION_NO_PERMITIDA` | 409 | Cambio de estado inválido | Incluir transiciones válidas si útil |
| `STOCK_INSUFICIENTE` | 409 | No hay stock/disponible | Incluir producto y faltante |
| `RESERVA_EXPIRADA_O_INVALIDA` | 409 | Reserva vencida/al intentar pagar | Sugerir volver a carrito |
| `IDEMPOTENCIA_CONFLICTO` | 409 | Clave usada con datos distintos | Raro, proteger |
| `WEBHOOK_FIRMA_INVALIDA` | 401 | Firma incorrecta | Sin detalles |
| `WEBHOOK_DUPLICADO` | 200 | `provider_event_id` ya procesado | Responder 200 (idempotente) |
| `DEMASIADOS_INTENTOS` | 429 | Rate limit | `Retry-After` |
| `ERROR_INTERNO` | 500 | Error no controlado | Genérico en prod |
| `SERVICIO_EXTERNO_FALLIDO` | 503 | Proveedor caído | Tolerante cuando aplique (DNI) |

> **Regla:** Errores operativos son `4xx`. Errores inesperados son `5xx`. Nunca exponer stack traces, SQL ni rutas internas en producción.

---

## 6. Seguridad en el API

| Medida | Aplicación |
|---|---|
| **Helmet + CSP** | En todas las respuestas HTTP |
| **CORS** | Solo `APP_URL` permitido |
| **Rate limiting** | Por IP. Más estricto en auth, crear pedido, webhook |
| **CSRF** | Para formularios del panel (POST/PUT/PATCH/DELETE) |
| **Cookies** | `HttpOnly`, `SameSite=Lax`, `Secure` (prod) |
| **Validación** | Zod en body/query/params |
| **Autorización** | Middleware por ruta + roles/permisos |
| **Idempotencia** | `Idempotency-Key` en crear pedido |
| **Firma webhook** | Verificación obligatoria + verificación cruzada |
| **Sanitización** | Evitar XSS. Usar escaping en plantillas si las hubiera |
| **No exponer errores** | Manejador central con redacción |

---

## 7. Versionado y evolución

- **Agregar campo**: generalmente compatible. Documentar.
- **Eliminar/cambiar tipo**: rompería contrato → nueva versión o mantener ambos con deprecación.
- **Nuevos endpoints**: siempre bajo `/api/v1` sin romper existentes.
- **Adaptadores**: pagos/DNI/correo/storage intercambiables sin cambiar contratos de API.

---

## 8. Notas de implementación

- **Stock disponible:** siempre calculado en SQL/servicio, nunca columna.
- **Precios:** tomados de `products` en el momento de validar/crear pedido. Nunca confiar en lo enviado.
- **Transacciones:** `sp_crear_pedido`, `sp_cambiar_estado_pedido`, `sp_venta_presencial` corren con transacción.
- **Historial inmutable:** solo INSERT.
- **Movimientos inmutables:** solo INSERT.
- **Código pedido:** generado por contador con `FOR UPDATE`.
- **Reservas:** limpias por job + validadas al crear pedido/pagar.

---

> **Siguiente paso:** `07-seguridad.md` con modelo de amenazas (STRIDE), matriz de controles y checklist de hardening.
