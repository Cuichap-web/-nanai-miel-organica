# ADR-007 — Adaptadores para integraciones externas

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Backend / Integraciones

---

## Contexto

El sistema integra con servicios que no controlamos y que pueden cambiar o no estar disponibles:

| Integración | Estado en v1 | Riesgo |
|---|---|---|
| **Pasarela de pagos** | Requerida | La API cambia, falla o rechaza una tarjeta |
| **Consulta de DNI** | Requerida | El proveedor no valida, cae o cambia su contrato |
| **Envío de correo** | Requerida | SMTP caído, cuota agotada |
| **Almacenamiento de archivos** | Local en v1 | El disco local no escala ni replica |
| **Pasarela / agente de envío** | Pendiente | Sin contrato definido |

## Decisión

Toda integración externa se encapsula en un **adaptador** con un contrato estable. El resto del sistema **nunca** habla con la API externa directamente: habla con el puerto.

### Estructura

```text
src/integrations/
├── pasarelaPagos/
│   ├── pasarelaPagos.interface.js   ← el contrato (puerto)
│   ├── pasarelaPagos.factory.js     ← elige la implementación
│   └── proveedores/
│       ├── pasarelaPrueba.js        ← simulación (v1, desarrollo y demos)
│       └── pasarelaCulqi.js         ← v2
├── consultaDni/
│   ├── consultaDni.interface.js
│   ├── consultaDni.factory.js
│   └── proveedores/
├── correo/
│   ├── correo.interface.js
│   └── proveedores/
└── almacenamiento/
    ├── almacenamiento.interface.js
    └── proveedores/
```

### Contrato de la pasarela de pagos

```js
// pasarelaPagos.interface.js
export const pasarelaPagos = {
  // Crea el intento de pago y devuelve los datos para el frontend.
  crearIntento({ monto, moneda, referencia, orden }): Promise<{
    idIntento: string,
    // Para redirigir al checkout del proveedor:
    urlCheckout?: string,
    // Para el cobro tokenizado en el navegador:
    tokenizacion?: { publishableKey: string, campos: object },
  }>,

  // Consulta el estado de un pago.
  consultarPago({ idIntento }): Promise<{
    estado: 'PENDIENTE' | 'APROBADO' | 'RECHAZADO' | 'REEMBOLSADO',
    codigoTransaccion?: string,
    monto: number,
    fechaAprobacion?: Date,
  }>,

  // Reembolsa. Puede ser no soportado por el proveedor.
  reembolsar({ idIntento, monto }): Promise<{ ok: boolean }>,

  // Verifica la firma del webhook.
  verificarWebhook({ cuerpo, cabeceras }): Promise<boolean>,
};
```

### Reglas

1. **Ninguna API externa se llama desde un controlador.** Solo desde un servicio, y siempre a través del puerto.
2. **Los errores externos se traducen** a errores internos (`PAGAMENTO_RECHAZADO`, `PASARELA_NO_DISPONIBLE`, `TIMEOUT_PASARELA`). El proveedor nunca expone su críptico al cliente final.
3. **Toda respuesta externa se valida con Zod** antes de usarse. Una API puede cambiar sin avisar.
4. **El tiempo de espera es explícito** (`timeout` por llamada) y los reintentos son **con espera creciente** y solo para operaciones idempotentes.
5. **Una implementación por defecto de prueba** (`pasarelaPrueba`) permite trabajar la v1 completa sincontratar pasarela, y sirve en las demos del proyecto.

## Alternativas consideradas

### Llamar a la API del proveedor directamente desde el servicio

Descartado. Cuando llegue la pasarela real (o el segundo proveedor de correo), habría que buscar y cambiar llamadas en varios servicios. Con el patrón Adaptador, se añade un archivo y se cambia **una línea** en la factory.

### Usar una librería genérica de "conector universal"

Descartado. Esas librerías (tipo `node-fetch` + reintentos genéricos) resuelven transporte, no semántica. Cada proveedor tiene su peculiar de autenticación, sus errores y su formato de webhook. Un "conector universal" termina siendo un `switch` gigante dentro de una dependencia.

### Definir la interfaz en TypeScript

Considerado. El proyecto es JavaScript, y la interfaz en JS con JSDoc cumple la misma función sin agregar toolchain de compilación. Si el proyecto pasa a TypeScript, las interfaces se convierten en `interface` sin cambiar los adaptadores.

### Un solo proveedor sin abstracción

Descartado. El requisito de extensibilidad es explícito, y además obliga a tener una implementación de prueba, que es valuable de todas formas.

## Consecuencias

**Positivas**
- Cambiar de pasarela no toca controladores, rutas ni la lógica de negocio.
- El sistema es **testeable sin internet**: los adaptadores se reemplazan por dobles en las pruebas.
- Se puede trabajar la v1 completa (incluidas las demos) sin contratar servicios de pago.
- Los errores externos quedan traducidos y documentados en un único lugar.

**Negativas / costos**
- Una capa de indirección extra por integración.
- El contrato debe mantenerse sincronizado con la reality del proveedor. La validación con Zod de cada respuesta es la que detecta esa desincronización (en desarrollo, no en producción).
- La implementación de prueba no debe filtrarse a producción: el factory debe leer el proveedor de `env.PAGOS_PROVEEDOR` y **fallar al arrancar** si se pide un proveedor inexistente.

**Impacto en el proyecto**
- `src/integrations/**` es el **único** lugar con `fetch`/`axios` hacia APIs externas.
- Las claves de API se leen de `env` y **nunca** se exponen al frontend. El frontend recibe solo la `publishableKey` y los datos de tokenización.
- `pasarelaPrueba` simula: aprobación, rechazo y timeout, para poder demostrar los tres flujos en la presentación del proyecto.
