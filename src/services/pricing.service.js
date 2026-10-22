const descuentos = [];

export const pricingService = {
  registrarProveedor(proveedor) {
    if (proveedor && typeof proveedor.esAplicable === 'function' && typeof proveedor.calcular === 'function') {
      descuentos.push(proveedor);
    }
  },

  calcular(items = [], contexto = {}) {
    let subtotal = 0;
    const lineas = items.map((item) => {
      const precioUnitario = Number(item.precio_unitario || item.precio || 0);
      const cantidad = Number(item.cantidad || 0);
      const subtotalLinea = precioUnitario * cantidad;
      subtotal += subtotalLinea;
      return {
        producto_id: item.producto_id,
        nombre_producto: item.nombre_producto || item.nombre,
        precio_unitario: precioUnitario,
        cantidad,
        subtotal_linea: subtotalLinea,
        descuento_unitario: 0,
        descuento_total: 0,
      };
    });

    let descuentoTotal = 0;
    for (const prov of descuentos) {
      try {
        if (prov.esAplicable(lineas, contexto)) {
          const res = prov.calcular(lineas, contexto);
          if (res && Number(res.descuento) > 0) {
            descuentoTotal += Number(res.descuento);
          }
        }
      } catch (e) {
        // Ignorar proveedor con error, no romper cálculo
      }
    }

    const costoEnvio = Number(contexto.costoEnvio || 0);
    const total = subtotal - descuentoTotal + costoEnvio;
    return { lineas, subtotal, descuentoTotal, costoEnvio, total };
  },
};

export default pricingService;
