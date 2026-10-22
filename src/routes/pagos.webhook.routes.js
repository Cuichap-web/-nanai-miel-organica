import { Router } from 'express';
import { pool } from '../config/db.js';

const router = Router();

router.post('/payments/webhook', async (req, res, next) => {
  try {
    const { event_id, pedido_codigo, estado, referencia_externa, respuesta } = req.body;
    if (!event_id || !pedido_codigo) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Datos incompletos' } });
    }
    const conn = await pool.getConnection();
    try {
      const [result] = await conn.query('CALL sp_aplicar_webhook_pago(?, ?, ?, ?, ?)', [
        event_id,
        pedido_codigo,
        estado || 'APROBADO',
        referencia_externa || null,
        JSON.stringify(respuesta || {}),
      ]);
      res.json({ success: true, data: result[0][0] });
    } finally {
      conn.release();
    }
  } catch (error) {
    if (error.message === 'PEDIDO_NO_EXISTE') {
      return res.status(404).json({ success: false, error: { code: 'ORDER_NOT_FOUND', message: 'Pedido no encontrado' } });
    }
    if (error.message === 'TRANSICION_NO_PERMITIDA') {
      return res.status(409).json({ success: false, error: { code: 'TRANSICION_NO_PERMITIDA', message: 'Transición no permitida' } });
    }
    next(error);
  }
});

export default router;
