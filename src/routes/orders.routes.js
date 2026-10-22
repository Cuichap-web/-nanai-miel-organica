import { Router } from 'express';
import { OrderModel } from '../models/order.model.js';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';

const router = Router();

function generarCodigo() {
  const year = new Date().getFullYear();
  const random = String(Math.floor(Math.random() * 1000000)).padStart(6, '0');
  return `NAN-${year}-${random}`;
}

router.post('/orders', async (req, res, next) => {
  try {
    const idempotencyKey = req.headers['idempotency-key'] || null;
    if (idempotencyKey) {
      const [existentes] = await pool.query('SELECT codigo FROM orders WHERE idempotency_key = ? LIMIT 1', [idempotencyKey]);
      if (existentes.length > 0) {
        const pedido = await OrderModel.findByCodigo(existentes[0].codigo);
        return res.status(200).json({ success: true, data: { codigo: existentes[0].codigo, pedido } });
      }
    }

    const { cliente, entrega, items } = req.body;
    if (!cliente || !entrega || !items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Datos incompletos' } });
    }

    let subtotal = 0;
    for (const item of items) {
      subtotal += Number(item.precio_unitario) * Number(item.cantidad);
    }
    const costoEnvio = entrega.modalidad === 'ENTREGA_LOCAL' ? 0 : 0;
    const total = subtotal + costoEnvio;
    const codigo = generarCodigo();

    const result = await OrderModel.createWithSP({
      codigo,
      tipoVenta: 'ONLINE',
      cliente,
      entrega,
      totales: { subtotal, costoEnvio, total },
      idempotencyKey,
      items,
      reservaTtl: env.RESERVA_TTL_MINUTOS,
    });

    const pedido = await OrderModel.findByCodigo(result.codigo);
    res.status(201).json({ success: true, data: { codigo: result.codigo, pedido } });
  } catch (error) {
    if (error.message === 'STOCK_INSUFICIENTE') {
      return res.status(409).json({ success: false, error: { code: 'STOCK_INSUFICIENTE', message: 'Stock insuficiente para uno o más productos' } });
    }
    next(error);
  }
});

router.get('/orders/track/:codigo', async (req, res, next) => {
  try {
    const pedido = await OrderModel.findByCodigo(req.params.codigo);
    if (!pedido) return res.status(404).json({ success: false, error: { code: 'ORDER_NOT_FOUND', message: 'Pedido no encontrado' } });
    res.json({ success: true, data: pedido });
  } catch (error) {
    next(error);
  }
});

export default router;
