import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { pool } from '../config/db.js';

const router = Router();

router.use(requireAuth);
router.use(requireRole('ADMIN', 'VENDEDOR'));

router.get('/dashboard', async (req, res, next) => {
  try {
    const [[{ totalPedidos }]] = await pool.query('SELECT COUNT(*) AS totalPedidos FROM orders');
    const [[{ pedidosPendientes }]] = await pool.query("SELECT COUNT(*) AS pedidosPendientes FROM orders o JOIN order_status s ON s.id = o.estado_id WHERE s.codigo IN ('PENDIENTE_PAGO','PAGO_POR_VERIFICAR','PENDIENTE_APROBACION')");
    const [[{ totalProductos }]] = await pool.query('SELECT COUNT(*) AS totalProductos FROM products WHERE activo = 1');
    res.json({ success: true, data: { totalPedidos, pedidosPendientes, totalProductos } });
  } catch (error) {
    next(error);
  }
});

router.get('/pedidos', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT o.id, o.codigo, o.tipo_venta, o.cliente_nombre, o.total, o.created_at,
              s.codigo AS estado_codigo, s.nombre AS estado_nombre
       FROM orders o JOIN order_status s ON s.id = o.estado_id
       ORDER BY o.created_at DESC LIMIT 100`
    );
    res.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

router.get('/pedidos/:id', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT o.*, s.codigo AS estado_codigo, s.nombre AS estado_nombre
       FROM orders o JOIN order_status s ON s.id = o.estado_id WHERE o.id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ success: false, error: { code: 'ORDER_NOT_FOUND', message: 'Pedido no encontrado' } });
    const [items] = await pool.query('SELECT * FROM order_items WHERE pedido_id = ?', [req.params.id]);
    res.json({ success: true, data: { pedido: rows[0], items } });
  } catch (error) {
    next(error);
  }
});

router.get('/productos', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT p.id, p.nombre, p.slug, p.precio, p.stock_fisico, p.activo, p.destacado, c.nombre AS categoria_nombre
       FROM products p JOIN categories c ON c.id = p.categoria_id ORDER BY p.created_at DESC`
    );
    res.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

router.get('/categorias', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT * FROM categories ORDER BY orden ASC');
    res.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

export default router;
