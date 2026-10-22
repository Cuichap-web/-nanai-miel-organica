import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { pool } from '../config/db.js';

const router = Router();

router.use(requireAuth);
router.use(requireRole('ADMIN', 'VENDEDOR'));

router.post('/pos/venta', async (req, res, next) => {
  try {
    const { cliente_nombre, medio_pago, items, notas } = req.body;
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Items requeridos' } });
    }
    const conn = await pool.getConnection();
    try {
      const [result] = await conn.query('CALL sp_venta_presencial(?, ?, ?, ?, ?)', [
        req.session.userId,
        cliente_nombre || 'Cliente mostrador',
        medio_pago || 'EFECTIVO',
        JSON.stringify(items),
        notas || null,
      ]);
      res.status(201).json({ success: true, data: result[0][0] });
    } finally {
      conn.release();
    }
  } catch (error) {
    if (error.message === 'STOCK_INSUFICIENTE') {
      return res.status(409).json({ success: false, error: { code: 'STOCK_INSUFICIENTE', message: 'Stock insuficiente' } });
    }
    next(error);
  }
});

router.get('/pos/ventas', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT * FROM sales_pos ORDER BY created_at DESC LIMIT 50');
    res.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

export default router;
