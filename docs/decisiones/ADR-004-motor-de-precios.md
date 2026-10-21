# ADR-004 — Motor de precios con IGV incluido y extensible a descuentos

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Dominio / Base de datos

---

## Contexto

El negocio vende en el mercado peruano, donde el IGV es 18 % y la convención del comercio minorista es mostrar el **precio final** al consumidor. Además, el sistema debe poder soportar en el futuro **cupones, promociones y descuentos** sin reescribir los módulos de productos, carrito, pedidos ni pagos.

## Decisión

### Parte A — IGV incluido

| Aspecto | Decisión |
|---|---|
| Precios en BD | `DECIMAL(10,2)` con **IGV 18 % ya incluido** |
| Bandera en pedido | `igv_incluido = 1` (fija en la v1) |
| Cálculo | El total = `subtotal + costo_envio`. El IGV **no** se suma por separado |
| Componente | `orders.subtotal` y `orders.total` guardan los importes finales que ve el cliente |

El IGV se desglosa **solo** en la boleta/reporte, como información informativa derivada (`total / 1.18`).

### Parte B — Motor de precios enchufable

El cálculo de precios vive en **un único servicio** (`pricing.service.js`) con una interfaz de proveedores de descuento:

```text
pricingService.calcular(items, contexto)
  ├─ 1. Resuelve precio unitario VIGENTE desde products   (nunca del cliente)
  ├─ 2. Calcula subtotal por línea
  ├─ 3. Aplica proveedores de descuento (lista VACÍA en la v1)
  ├─ 4. Aplica costo de envío según zona/modalidad
  └─ 5. Devuelve líneas + totales con desglose
```

**Contrato de un proveedor de descuento (futuro):**

```js
{
  codigo: 'CUPON10',
  esAplicable: (items, contexto) => boolean,
  calcular: (items, contexto) => { descuento, detalle }
}
```

### Parte C — Snapshot en las líneas

`order_items` guarda `precio_unitario`, `cantidad` y `subtotal_linea` **congelados** en el momento de la compra. Si el precio del producto cambia mañana, el pedido de ayer no se recalcula. Añadir `descuento_unitario` y `descuento_total` a `order_items` **desde ahora** (en `0.00` en la v1) evita una migración de datos histórica cuando existan cupones.

## Alternativas consideradas

### Parte A — Precio sin IGV, se suma en el checkout

| A favor | En contra |
|---|---|
| Desglose visible del impuesto | El cliente ve "S/ 45.00 + IGV S/ 8.10 = S/ 53.10" — fricción y confusión |
| Contabilidad más directa | Cada línea necesita guardar base + IGV calculada → más columnas, más errores de redondeo |
| | No coincide con lo que el negocio anuncia en redes sociales |

**Descartado** por la convención del mercado minorista peruano. **Reconsiderable** si el negocio empieza a vender a empresas que piden factura con desglose (empresas que compran en Perú suelen necesitar el IGV desglosado, y eso se resuelve en la boleta, no en el catálogo).

### Parte A alterno — Almacenar base e IGV por separado en `products`

Descartado por la misma razón: duplica la información y obliga a elegir en **cada** lectura qué campo usar. Un solo campo "precio final" elimina la clase de bug más común en e-commerce: sumar IGV dos veces.

### Parte B — Implementar cupones ya en la v1

Descartado por alcance. Pero la **estructura** sí se prepara:

| Decisión | Motivo |
|---|---|
| El motor de precios es un **servicio único** | Ningún módulo calcula totals por su cuenta |
| La lista de descuentos está **vacía**, pero la interfaz existe | Añadir un cupón = añadir un archivo, no refactorizar |
| `order_items` ya tiene columnas de descuento en `0.00` | Sin migración de histórico al activar cupones |
| `pricingService` es el **único** que toca precios | Cambiar la regla de descuentos no afecta a carrito, pedidos ni pagos |

## Consecuencias

**Positivas**
- El carrito, el checkout y los reportes comparten **exactamente el mismo** cálculo. Impossible que discrepen.
- Activar cupones: añadir la tabla `discounts`, añadir el proveedor, y nada más.
- El histórico de pedidos es inmutable en sus importes.
- No hay `FLOAT` en el sistema: `DECIMAL(10,2)` en todas partes. Los errores de coma flotante en dinero son la causa clásica de descuadres de un céntimo.

**Negativas / costos**
- El IGV no se desglosa en la vista del checkout. Se puede mostrar "(IGV incluido)" como etiqueta informativa. El desglose real va en la boleta.
- Guardar `descuento_unitario = 0.00` es una columna "muerta" en la v1. Es un costo consciente asumido a cambio de no migrar el histórico.
- `DECIMAL` en JS: `mysql2` devuelve `DECIMAL` como **string** por defecto (para no perder precisión). El motor de precios deberá convertir con cuidado. **Se documentará en el código.**

**Impacto en el proyecto**
- `pricing.service.js` es el único que produce importes.
- `order_items` incluye `descuento_unitario DECIMAL(10,2) NOT NULL DEFAULT 0.00` y `descuento_total DECIMAL(10,2) NOT NULL DEFAULT 0.00`.
- La API de validación del carrito devuelve el desglose de totales, para que el frontend **muestre** lo que el servidor calculó.
