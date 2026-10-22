import { Router } from 'express';
import { pool } from '../config/db.js';

const router = Router();

router.get('/health', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT 1 as ok');
    res.json({
      success: true,
      data: {
        status: 'ok',
        db: rows[0].ok === 1 ? 'up' : 'down',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
      },
    });
  } catch (error) {
    next(error);
  }
});

export default router;
