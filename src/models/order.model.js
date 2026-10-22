import { pool } from '../config/db.js';

export const OrderModel = {
  async createWithSP({ codigo, tipoVenta, cliente, entrega, totales, idempotencyKey, items, reservaTtl }) {
    const conn = await pool.getConnection();
    try {
      const [result] = await conn.query('CALL sp_crear_pedido(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        codigo,
        tipoVenta,
        cliente.nombre,
        cliente.email || null,
        cliente.telefono,
        cliente.dni || null,
        entrega.direccion || null,
        entrega.zonaDistrito || null,
        entrega.modalidad,
        totales.subtotal,
        totales.costoEnvio,
        totales.total,
        idempotencyKey || null,
        null,
        JSON.stringify(items),
        reservaTtl,
      ]);
      return result[0][0];
    } finally {
      conn.release();
    }
  },

  async findByCodigo(codigo) {
    const [rows] = await pool.query(
      `SELECT o.codigo, o.tipo_venta, o.subtotal, o.costo_envio, o.total, o.reserva_expira_en, o.created_at,
              s.codigo AS estado_codigo, s.nombre AS estado_nombre
       FROM orders o
       JOIN order_status s ON s.id = o.estado_id
       WHERE o.codigo = ? LIMIT 1`,
      [codigo]
    );
    return rows[0] || null;
  },
};
