export const pasarelaPrueba = {
  async crearIntento({ monto, moneda = 'PEN', referencia }) {
    return {
      idIntento: `TEST-${Date.now()}`,
      urlCheckout: null,
      tokenizacion: {
        publishableKey: 'pk_test_demo',
        campos: { monto, moneda, referencia },
      },
      modo: 'prueba',
    };
  },
  async consultarPago({ idIntento }) {
    return {
      estado: 'PENDIENTE',
      codigoTransaccion: idIntento,
      monto: 0,
    };
  },
  async verificarWebhook({ cuerpo }) {
    return Boolean(cuerpo);
  },
};

export default pasarelaPrueba;
