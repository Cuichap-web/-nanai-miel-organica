import { Router } from 'express';
import { pool } from '../config/db.js';

const router = Router();

router.post('/jobs/expirar-reservas', async (req, res, next) => {
  try {
    const conn = await pool.getConnection();
    try {
      await conn.query('CALL sp_expirar_reservas()');
      res.json({ success: true, message: 'Reservas expiradas procesadas' });
    } finally {
      conn.release();
    }
  } catch (error) {
    next(error);
  }
});

export default router;
