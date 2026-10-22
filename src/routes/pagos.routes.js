import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { pool } from '../config/db.js';

const router = Router();

router.use(requireAuth);
router.use(requireRole('ADMIN', 'VENDEDOR'));

router.post('/pagos/:pedidoId/verificar', async (req, res, next) => {
  try {
    const { pedidoId } = req.params;
    const { estado, motivo } = req.body; // APROBADO o RECHAZADO
    if (!['APROBADO', 'RECHAZADO'].includes(estado)) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Estado inválido' } });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [pagos] = await conn.query('SELECT id FROM payments WHERE pedido_id = ? ORDER BY created_at DESC LIMIT 1 FOR UPDATE', [pedidoId]);
      if (pagos.length === 0) {
        await conn.rollback();
        return res.status(404).json({ success: false, error: { code: 'PAYMENT_NOT_FOUND', message: 'Pago no encontrado' } });
      }

      await conn.query('UPDATE payments SET estado = ?, verificado_por = ?, fecha_verificacion = NOW() WHERE id = ?', [
        estado === 'APROBADO' ? 'APROBADO' : 'RECHAZADO',
        req.session.userId,
        pagos[0].id,
      ]);

      if (estado === 'APROBADO') {
        await conn.query('CALL sp_cambiar_estado_pedido(?, ?, ?, ?, ?)', [pedidoId, 'PAGADO', req.session.userId, motivo || 'Pago verificado manualmente', null, null]);
      } else {
        await conn.query('CALL sp_cambiar_estado_pedido(?, ?, ?, ?, ?)', [pedidoId, 'CANCELADO', req.session.userId, motivo || 'Pago rechazado', null, null]);
      }

      await conn.commit();
      res.json({ success: true, message: `Pago ${estado.toLowerCase()}` });
    } catch (error) {
      await conn.rollback();
      throw error;
    } finally {
      conn.release();
    }
  } catch (error) {
    if (error.message === 'TRANSICION_NO_PERMITIDA') {
      return res.status(409).json({ success: false, error: { code: 'TRANSICION_NO_PERMITIDA', message: 'Transición no permitida' } });
    }
    next(error);
  }
});

export default router;
